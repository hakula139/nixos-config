# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **flake-based NixOS / nix-darwin configuration** managing multiple systems from a single declarative codebase:

- **5 NixOS servers** (us-1, us-2, us-3, us-4, sg-1) on x86_64-linux
- **1 macOS workstation** (hakula-macbook) on aarch64-darwin
- **1 generic Linux** (hakula-work) using standalone Home Manager
- **1 Docker image** (hakula-devvm) for air-gapped deployment

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
home-manager switch --flake '.#hakula-work'
# or with alias: nixsw hakula-work

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

#### Re-keying Secrets

When adding or changing host / user keys in `secrets/keys.nix`, all `.age` files must be re-encrypted with the updated recipient list. Run from an **interactive terminal** (not from scripts or Claude Code's Bash tool):

```bash
cd secrets
agenix -r -i ~/.ssh/<private-key>
```

**Warning**: `agenix -r` must run in an interactive terminal. The agenix script checks `[ -t 0 ]` and overrides `EDITOR` to `cp -- /dev/stdin` when stdin is not a TTY, which silently empties all secrets before re-encrypting them.

## Architecture

### Flake Structure (`flake.nix`)

The flake uses a **builder function pattern** to reduce duplication:

- `mkServer`: Creates NixOS configurations with agenix, disko, and Home Manager integrated
- `mkDarwin`: Creates Darwin configurations with agenix and Home Manager integrated
- `mkHome`: Creates standalone Home Manager configurations for non-NixOS Linux
- `mkDocker`: Creates NixOS Docker images with nixos-generators for air-gapped deployment
- `overlays`: Provides `unstable` packages, `agenix` CLI, and custom packages (`cloudreve`, `github-mcp-server`)
- `forAllSystems`: Handles both x86_64-linux and aarch64-darwin

**Key outputs**:

- `nixosConfigurations.*`: Server configurations (us-1, us-2, us-3, us-4, sg-1)
- `darwinConfigurations.hakula-macbook`: macOS configuration
- `homeConfigurations.hakula-work`: Standalone Home Manager for generic Linux
- `packages.x86_64-linux.hakula-devvm-docker`: Docker image for air-gapped deployment
- `checks.*.pre-commit`: Pre-commit hook validation
- `devShells.default`: Development environment with pre-commit hooks
- `formatter`: nixfmt-rfc-style

### Directory Layout

```text
.
├── flake.nix                    # Main entry point
├── hosts/                       # Per-host configurations
│   ├── _profiles/               # Reusable hardware / boot / container profiles
│   │   ├── disk-config.nix      # Shared GPT + ext4 disk layout
│   │   ├── cloudcone-sc2/       # CloudCone SC2 hardware profile (MBR, own disk layout)
│   │   ├── cloudcone-vps/       # CloudCone VPS hardware profile
│   │   ├── dmit/                # DMIT hardware profile
│   │   ├── docker/              # Docker container profile
│   │   └── tencent-lighthouse/  # Tencent Lighthouse hardware profile
│   ├── us-1/                    # CloudCone SC2 server
│   ├── us-2/                    # CloudCone VPS
│   ├── us-3/                    # CloudCone SC2 server
│   ├── us-4/                    # DMIT server
│   ├── sg-1/                    # Tencent Lighthouse server
│   ├── hakula-macbook/          # macOS workstation
│   ├── hakula-work/             # Work PC (WSL)
│   └── hakula-devvm/            # DevVM (Docker image for air-gapped deployment)
├── modules/
│   ├── shared.nix               # Cross-platform base config
│   ├── nixos/                   # NixOS service modules (21 modules)
│   └── darwin/                  # macOS-specific modules (with ssh/ submodule)
├── home/
│   ├── hakula.nix               # Main user configuration entry
│   └── modules/                 # Home Manager modules
│       ├── claude-code/         # Claude Code configuration
│       ├── cursor/              # Cursor editor config
│       ├── git/                 # Git configuration
│       ├── mcp/                 # MCP server definitions (shared)
│       ├── mihomo/              # Mihomo proxy client
│       ├── nix/                 # User-level nix.conf for standalone HM
│       ├── ssh/                 # SSH client config
│       ├── syncthing/           # Syncthing file synchronization
│       ├── wakatime/            # Wakatime time tracking
│       ├── zsh/                 # Shell configuration
│       ├── darwin.nix           # macOS user-level settings
│       └── shared.nix           # Shared module configuration
├── packages/                    # Custom package definitions
├── lib/
│   ├── secrets.nix              # Secrets helper library
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
- **Services**: `aria2`, `cloudreve`, `clove`, `fuclaude`, `netdata`, `piclist`, `umami`, `wakatime`
- **System**: `backup`, `builders`, `cachix`, `claude-code`, `cloudcone`, `cloudflare`, `dockerhub`, `mcp`, `ssh`

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

- **User keys**: `hakula-cloudcone`, `hakula-dmit`, `hakula-tencent` (for remote management)
- **Host keys**: `us-1`, `us-2`, `us-3`, `us-4`, `sg-1` (for host decryption)
- **Workstation keys**: `hakula-macbook`, `hakula-work` (for local editing)

Secrets in `secrets/*.age` are **decrypted at activation time** by agenix and placed in `/run/agenix` (NixOS) or `/run/agenix.d` (Darwin). Reference them in modules via `config.age.secrets.<secret-name>.path`.

#### Secrets Helper Library (`lib/secrets.nix`)

All modules use centralized helper functions from `lib/secrets.nix` to declare secrets with consistent configuration:

**For NixOS modules:**

```nix
age.secrets.my-secret = secrets.mkSecret {
  scope = "shared";        # Optional: secret scope directory (defaults to "shared")
  name = "my-secret";      # Secret file name
  owner = "service-user";  # File owner
  group = "service-group"; # File group
  mode = "0400";           # Optional: file permissions (defaults to "0400")
  path = "/custom/path";   # Optional: custom destination path
};
```

**For Home Manager modules:**

```nix
age.secrets.my-secret = secrets.mkHomeSecret {
  scope = "shared";        # Optional: secret scope directory (defaults to "shared")
  name = "my-secret";      # Secret file name
  homeDir = homeDir;       # User's home directory
  mode = "0400";           # Optional: file permissions (defaults to "0400")
  path = "/custom/path";   # Optional: custom destination path
};
```

**Parameters:**

- `scope` (optional): Secret scope directory, defaults to `"shared"` (secrets stored in `secrets/shared/`)
- `name` (required): Secret filename (without `.age` extension)
- `owner` / `group` (NixOS only): File ownership for decrypted secret
- `homeDir` (Home Manager only): User's home directory for path construction
- `mode` (optional): File permissions, defaults to `"0400"` (read-only for owner)
- `path` (optional): Custom destination path; if omitted, uses default location

**Helper functions:**

- `mkSecret`: Creates NixOS system-level secret configuration
- `mkHomeSecret`: Creates Home Manager user-level secret configuration
- `mkSecretsDir`: Generates systemd tmpfiles rule for secrets directory (NixOS)
- `mkHomeSecretsDir`: Generates home activation script for secrets directory (Home Manager)

## CI/CD Pipeline

**GitHub Actions** (`.github/workflows/ci.yml`):

1. **Flake Check**: Validates flake structure (`nix flake check --all-systems`)
2. **Build Matrix**: Builds 4 configurations in parallel
   - NixOS: `us-4` (x86_64-linux)
   - macOS: `hakula-macbook` (aarch64-darwin)
   - Generic Linux: `hakula-work` (x86_64-linux)
   - Docker: `hakula-devvm-docker` (x86_64-linux)

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
nix build '.#nixosConfigurations.us-4.config.system.build.toplevel'
nix build '.#darwinConfigurations.hakula-macbook.system'
nix build '.#homeConfigurations.hakula-work.activationPackage'
nix build '.#packages.x86_64-linux.hakula-devvm-docker'
```

## Common Patterns

### Adding a New NixOS Module

1. Create `modules/nixos/my-service/default.nix` (directory-based preferred)
2. Define `options.services.my-service.enable` and configuration options
3. Use `lib.mkIf config.services.my-service.enable { ... }` for conditional activation
4. Import in host configuration and set `services.my-service.enable = true;`
5. **Maintain alphabetical ordering** of services within the host configuration's Services section

### Adding a Home Manager Module

1. Create `home/modules/my-module/default.nix` (directory-based preferred)
2. Accept `{ config, pkgs, lib, isNixOS ? false, isDesktop ? false, ... }`
3. Use `lib.mkIf` to conditionally enable based on `isNixOS` or `isDesktop`
4. Import in `home/hakula.nix`

### Adding a Custom Package

1. Create `packages/my-package/default.nix`
2. Follow standard Nix package structure (`stdenv.mkDerivation` or `buildGoModule`, etc.)
3. Add to `overlays` in `flake.nix`: `my-package = final.callPackage ./packages/my-package { };`
4. Reference as `pkgs.my-package` in modules

### Adding a Host

1. Create `hosts/my-host/default.nix` with host-specific configuration
2. Add to `nixosConfigurations`, `darwinConfigurations`, or `homeConfigurations` in `flake.nix` using the appropriate builder (`mkServer`, `mkDarwin`, or `mkHome`)
3. For NixOS: generate hardware config with `nixos-generate-config --show-hardware-config`
4. Optionally reuse profiles from `hosts/_profiles/` for common hardware

### Adding a Docker Image

1. Create `hosts/my-container/default.nix` with container-specific configuration
2. Import the docker profile: `imports = [ ../_profiles/docker ];`
3. Set `networking.hostName` and any host-specific overrides
4. Add Home Manager overrides under `home-manager.users.hakula = { ... };` if needed
5. Add to `packages.x86_64-linux` in `flake.nix` using `mkDocker`
6. Build with `nix build '.#packages.x86_64-linux.my-container-docker'`

### Adding Secrets to a Module

1. Add `secrets` parameter to the module's function signature (if not already present)
2. Declare the secret using the helper library:
   - **NixOS**: `age.secrets.<name> = secrets.mkSecret { name = "..."; owner = "..."; group = "..."; };`
   - **Home Manager**: `age.secrets.<name> = secrets.mkHomeSecret { name = "..."; homeDir = homeDir; };`
3. Create the encrypted secret file: `cd secrets/shared && agenix -e <name>.age`
4. Reference the secret in your module via `config.age.secrets.<name>.path`
5. Optional: Override `mode` or `path` parameters if custom permissions or location needed

## Proxy Configuration

Some hosts use **HTTP proxy** (`http://127.0.0.1:7897`) for Claude Code and other tools. This is configured per-host via `hakula.claude-code.proxy.enable = true` in the host's `default.nix`. Currently enabled on:

- `hakula-macbook`
- `hakula-work`

When working with network operations on these hosts, be aware that tools may route through this proxy.
