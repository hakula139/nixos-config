# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Repository Overview

This is a **flake-based NixOS / nix-darwin configuration** managing multiple systems from a single declarative codebase:

- **4 NixOS servers** (us-1, us-2, us-3, sg-1) on x86_64-linux
- **1 macOS workstation** (hakula-macbook) on aarch64-darwin
- **1 generic Linux** (hakula-linux) using standalone Home Manager

The architecture emphasizes modularity, with shared base configuration in `modules/shared.nix` and per-host customization in `hosts/`.

## Essential Commands

### Building and Deployment

```bash
# NixOS servers
sudo nixos-rebuild switch --flake '.#us-1'
# or with alias: nixsw us-1

# macOS (after bootstrap)
sudo darwin-rebuild switch --flake '.#hakula-macbook'
# or with alias: nixsw hakula-macbook

# Generic Linux (Home Manager standalone)
home-manager switch --flake '.#hakula-linux'
# or with alias: nixsw hakula-linux

# Update all dependencies
nix flake update
```

### Bootstrap Commands

```bash
# First-time NixOS installation with nixos-anywhere
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>

# First-time macOS setup
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#hakula-macbook'
```

### Code Quality

```bash
# Format all Nix files
git ls-files '*.nix' -z | xargs -0 nix fmt

# Enable pre-commit hooks locally
nix develop -c zsh

# Run CI-style validation (non-modifying)
nix flake check
```

### Development Environment

```bash
# Enter development shell with all tooling
nix develop -c zsh

# Available tools include:
# - Nix: cachix, deadnix, nil, nix-tree, nixfmt-rfc-style, nom, nvd, statix
# - Secrets: age, agenix
```

### Secrets Management

```bash
cd secrets
agenix -e <secret-name>.age -i ~/.ssh/<private-key>
```

## Architecture

### Flake Structure (`flake.nix`)

The flake uses a **builder function pattern** to reduce duplication:

- `mkServer`: Creates NixOS configurations with agenix, disko, and Home Manager integrated
- `overlays`: Provides `unstable` packages, `agenix` CLI, and custom `cloudreve` package
- `forAllSystems`: Handles both x86_64-linux and aarch64-darwin

**Key outputs**:

- `nixosConfigurations.*`: Server configurations (us-1, us-2, us-3, sg-1)
- `darwinConfigurations.hakula-macbook`: macOS configuration
- `homeConfigurations.hakula-linux`: Standalone Home Manager for generic Linux
- `checks.*.pre-commit`: Pre-commit hook validation
- `devShells.default`: Development environment with pre-commit hooks
- `formatter`: nixfmt-rfc-style

### Directory Layout

```text
.
├── flake.nix                    # Main entry point
├── hosts/                       # Per-host configurations
│   ├── _profiles/               # Reusable hardware / boot profiles
│   ├── us-1/                    # CloudCone SC2 server
│   ├── us-2/                    # CloudCone VPS
│   ├── us-3/                    # CloudCone SC2 server
│   ├── sg-1/                    # Tencent Lighthouse server
│   └── hakula-macbook/          # macOS workstation
├── modules/
│   ├── shared.nix               # Cross-platform base config
│   ├── nixos/                   # NixOS service modules (18 modules)
│   └── darwin/                  # macOS-specific modules
├── home/
│   ├── hakula.nix               # Main user configuration entry
│   └── modules/                 # Home Manager modules
│       ├── claude-code/         # Claude Code configuration
│       ├── cursor/              # Cursor editor config
│       ├── git/                 # Git configuration
│       ├── ssh/                 # SSH client config
│       ├── zsh/                 # Shell configuration
│       ├── mcp.nix              # MCP server definitions
│       └── darwin.nix           # macOS user-level settings
├── packages/                    # Custom package definitions
├── lib/
│   └── tooling.nix              # Shared development tools
├── secrets/                     # agenix-encrypted secrets
│   ├── keys.nix                 # SSH public keys for age encryption
│   └── secrets.nix              # Age recipient configuration
└── .github/
    ├── workflows/ci.yml         # CI pipeline
    └── actions/setup-nix/       # Reusable Nix setup action
```

### Module System

**NixOS modules** (`modules/nixos/`) are **optionally enabled** services configured per-host. Key modules:

- **Infrastructure**: `nginx`, `xray`, `clash`, `postgresql`, `podman`
- **Services**: `aria2`, `cloudreve`, `piclist`, `umami`, `fuclaude`, `netdata`
- **System**: `backup`, `ssh`, `cachix`, `cloudcone`, `dockerhub`, `mcp`

Each module typically exports an `enable` option and service-specific configuration. Host configurations import modules and enable them selectively.

**Home Manager modules** (`home/modules/`) configure user environments. The `isNixOS` and `isDesktop` flags control conditional configuration (e.g., NixOS vs. standalone, desktop vs. server).

### Shared Configuration Pattern

`modules/shared.nix` exports **cross-platform primitives**:

- `sshKeys`: User SSH public keys from `secrets/keys.nix`
- `basePackages`: Minimal system packages (curl, wget, git, htop, vim)
- `fonts`: Nerd Fonts, Sarasa Gothic, Source Han Sans/Serif
- `cachix`: Binary cache configuration for "hakula" cache
- `nixTooling`: Development tools from `lib/tooling.nix`
- `nixSettings`: Experimental features, buffer sizes

Host configurations import `shared.nix` and extend with platform/host-specific settings.

### Secrets with agenix

Secrets are encrypted with **age** using SSH keys defined in `secrets/keys.nix`:

- **User keys**: `hakula-cloudcone`, `hakula-tencent` (for remote management)
- **Host keys**: us-1, us-2, us-3, sg-1 (for host decryption)
- **Workstation keys**: hakula-macbook, hakula-work (for local editing)

Secrets in `secrets/*.age` are **decrypted at activation time** by agenix and placed in `/run/agenix` (NixOS) or `/run/agenix.d` (Darwin). Reference them in modules via `config.age.secrets.<secret-name>.path`.

## CI/CD Pipeline

**GitHub Actions** (`.github/workflows/ci.yml`):

1. **Flake Check**: Validates flake structure (`nix flake check --all-systems`)
2. **Build Matrix**: Builds three configurations in parallel
   - NixOS: `us-1` (x86_64-linux)
   - Generic Linux: `hakula-linux` (x86_64-linux)
   - macOS: `hakula-macbook` (aarch64-darwin)

**Cachix integration**: Builds are cached in the "hakula" cache. Uploads to Cachix happen on `main` branch or when the actor is `hakula139`.

**Pre-commit hooks** run in CI via `nix flake check`:

- `check-added-large-files`
- `check-yaml`
- `end-of-file-fixer`
- `trim-trailing-whitespace`
- `nixfmt-rfc-style`

## Code Style

### Nix

- **Formatter**: `nixfmt-rfc-style` (enforced by pre-commit)
- **Line width**: Default (100 characters)
- **Import style**: Use `with pkgs;` in package lists for brevity
- **Module structure**: Follow existing module patterns (enable option, config block, documentation strings)
- **Comments**: Only add when needed; avoid verbose / obvious comments (prefer clarity in naming / structure)

### Bash Scripts

**Formatting principles** - DRY the logic, but expand the formatting:

- Use **multi-line formatting** for complex commands: `if/else` blocks, multi-argument `printf`, process substitutions
- Use **descriptive variable names**

## Testing Changes

Before pushing, always run:

```bash
nix flake check  # Validates flake + runs pre-commit checks
```

For host-specific testing:

```bash
# Build without activating (faster feedback)
nix build '.#nixosConfigurations.us-1.config.system.build.toplevel'
nix build '.#darwinConfigurations.hakula-macbook.system'
nix build '.#homeConfigurations.hakula-linux.activationPackage'
```

## Common Patterns

### Adding a New NixOS Module

1. Create `modules/nixos/my-service/default.nix`
2. Define `options.services.my-service.enable` and configuration options
3. Use `lib.mkIf config.services.my-service.enable { ... }` for conditional activation
4. Import in host configuration and set `services.my-service.enable = true;`
5. **Maintain alphabetical ordering** of services within the host configuration's Services section

### Adding a Home Manager Module

1. Create `home/modules/my-module.nix` (or `my-module/default.nix`)
2. Accept `{ config, pkgs, lib, isNixOS ? false, isDesktop ? false, ... }`
3. Use `lib.mkIf` to conditionally enable based on `isNixOS` or `isDesktop`
4. Import in `home/hakula.nix`

### Adding a Custom Package

1. Create `packages/my-package/default.nix`
2. Follow standard Nix package structure (`stdenv.mkDerivation` or `buildGoModule`, etc.)
3. Add to `overlays` in `flake.nix`: `my-package = final.callPackage ./packages/my-package { };`
4. Reference as `pkgs.my-package` in modules

### Adding a Host

1. Create `hosts/my-host/default.nix` with hardware configuration
2. Add to `nixosConfigurations` (or `darwinConfigurations`) in `flake.nix` using `mkServer` or `nix-darwin.lib.darwinSystem`
3. Generate hardware config: `nixos-generate-config --show-hardware-config`
4. Optionally reuse profiles from `hosts/_profiles/` for common hardware

## Proxy Configuration

The repository uses **HTTP proxy** (127.0.0.1:7897) for Claude Code and other tools. This is configured in `home/modules/claude-code/default.nix`:

```nix
env = {
  HTTPS_PROXY = "http://127.0.0.1:7897";
  HTTP_PROXY = "http://127.0.0.1:7897";
  NO_PROXY = "localhost,127.0.0.1";
};
```

When working with network operations, be aware that tools may route through this proxy.
