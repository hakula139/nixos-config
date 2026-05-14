# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **flake-based NixOS / nix-darwin configuration** managing multiple systems from a single declarative codebase:

- **5 NixOS servers** (us-1, us-2, us-3, us-4, sg-1) on x86_64-linux
- **1 macOS workstation** (hakula-macbook) on aarch64-darwin
- **1 generic Linux** (hakula-linux) using standalone Home Manager
- **1 Docker image** (hakula-devvm) for air-gapped deployment

The architecture emphasizes modularity, with shared base configuration in `modules/shared.nix` and per-host customization in `hosts/`.

## Essential Commands

### Building and Deployment

```bash
# NixOS servers (run on the server itself)
nh os switch .
# or with alias: nixsw

# NixOS servers (multi-server deployment from workstation via Colmena)
colmena apply                  # all servers in parallel
colmena apply --on us-4        # single server
colmena apply --on @cloudcone  # by provider tag

# macOS (after bootstrap)
nh darwin switch .
# or with alias: nixsw

# Generic Linux (Home Manager standalone)
nh home switch . -c hakula-linux
# or with alias: nixsw

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

# Lint with statix (anti-patterns) and deadnix (unused bindings)
statix check .
deadnix --fail .

# Enable pre-commit hooks locally
nix develop -c zsh

# Run CI-style validation (non-modifying)
nix flake check
```

### Development Environment

```bash
# Enter development shell (tooling declared in lib/tooling.nix)
nix develop -c zsh
```

### Secrets Management

```bash
cd secrets
agenix -e <service>/<name>.age -i ~/.ssh/<private-key>
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

- `serverSharedModules`: Common NixOS modules (agenix, disko, Home Manager) shared by `mkServer` and Colmena
- `mkServer`: Creates NixOS configurations with agenix, disko, and Home Manager integrated
- `mkDarwin`: Creates Darwin configurations with agenix and Home Manager integrated
- `mkHome`: Creates standalone Home Manager configurations for non-NixOS Linux
- `mkDocker`: Creates layered NixOS Docker images using `dockerTools.buildLayeredImageWithNixDb` for air-gapped deployment
- `overlays`: Provides `unstable` packages, `agenix` CLI, custom packages (`cloudreve`, `mcp-server-*`), and a patched `peertube`
- `inputs.llm-agents`: Provides `claude-code` and `codex` packages from [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix)
- `forAllSystems`: Handles both x86_64-linux and aarch64-darwin

### Directory Layout

- `flake.nix` — main entry point; outputs `nixosConfigurations`, `darwinConfigurations`, `homeConfigurations`, `packages`, `colmena`, `checks`, `devShells`, `formatter`
- `hosts/` — per-host configurations; `hosts/_profiles/` holds reusable hardware / container profiles
- `modules/shared.nix` — cross-platform base config
- `modules/nixos/` — optional NixOS service modules (enabled per-host)
- `modules/darwin/` — macOS-specific modules
- `home/hakula.nix` + `home/modules/` — Home Manager user configuration
- `packages/` — custom package definitions
- `lib/` — shared helpers (`caches.nix`, `corp-domain.nix`, `secrets.nix`, `servers.nix`, `tooling.nix`; `llm-assistants/` for assistant-specific helpers and Claude profile sets)
- `secrets/` — agenix-encrypted secrets (`keys.nix` for SSH public keys, `secrets.nix` for recipient mapping)
- `.github/workflows/ci.yml` — CI pipeline

### Module System

NixOS modules in `modules/nixos/` are **optionally enabled** services, each exporting an `enable` option. Host configurations import and enable them selectively.

The `llm-assistants` module acts as an integration layer for the primary interactive user, nesting `claude-code` and `mcp` sub-modules that mirror the `home/modules/llm-assistants/` structure.

Home Manager modules in `home/modules/` configure user environments. The `isNixOS` and `isDesktop` flags drive conditional configuration (e.g., NixOS vs. standalone, desktop vs. server).

### Shared Configuration Pattern

`modules/shared.nix` exports **cross-platform primitives**:

- `sshKeys`: User SSH public keys from `secrets/keys.nix`
- `basePackages`: Minimal system packages (curl, wget, git, htop, vim)
- `fonts`: Nerd Fonts, Sarasa Gothic, Source Han Sans/Serif
- `binaryCaches`: Binary cache substituters and public keys from `lib/caches.nix`
- `nixTooling`: Development tools from `lib/tooling.nix`
- `nixSettings`: Experimental features, buffer sizes
- `servers`: Server inventory imported from `lib/servers.nix` (IP, port, provider, host keys, builder config)

Host configurations import `shared.nix` and extend with platform/host-specific settings.

### Secrets with agenix

Secrets are encrypted with **age** using SSH keys declared in `secrets/keys.nix` (grouped as `users` / `hosts` / `workstations`). Recipient rules live in `secrets/secrets.nix`.

Secrets live in `secrets/` nested by service (e.g., `secrets/llm-assistants/claude-oauth-token.age`, `secrets/peertube/env.age`). They are **decrypted at activation time** by agenix. Reference them in platform modules via `config.age.secrets.<attr-name>.path`.

#### Secrets Helper Library (`lib/secrets.nix`)

All platform modules materialize secrets through `age.secrets`. NixOS, Darwin, and system-manager collect user secret requirements from `home-manager.users.<user>.hakula.secrets.required`, then convert them with `secrets.mkRequiredUserSecrets`.

**NixOS modules:**

```nix
age.secrets.my-secret = secrets.mkSecret {
  name = "my-service/my-secret"; # Path under secrets/ (sans .age)
  owner = "service-user";
  group = "service-group";
};
```

**Home Manager modules:**

```nix
hakula.secrets.required."my-service/my-secret" = { };
```

Set `path` only when a tool requires a fixed destination:

```nix
hakula.secrets.required."my-service/my-secret" = {
  path = "${config.home.homeDirectory}/.my-secret";
};
```

The requirement attr name is the logical key used by Home Manager consumers. The attrset form accepts optional `name` (encrypted source path, defaulting to the logical key), `mode` (defaults to `"0400"`), and `path` (custom destination). Home Manager secret requirements default to runtime `age.secrets` paths under `/run/agenix`.

Reference declared Home Manager secrets through the shared resolver:

```nix
config.hakula.secrets.path "<logical-key>"
```

## CI/CD Pipeline

GitHub Actions (`.github/workflows/ci.yml`) runs on every push / PR:

1. `nix flake check --all-systems` — validates flake structure and runs pre-commit hooks (`nixfmt`, `statix`, `deadnix`, `check-added-large-files`, `check-yaml`, `end-of-file-fixer`, `trim-trailing-whitespace`).
2. Parallel builds of every host config (`us-1`..`us-4`, `sg-1`, `hakula-macbook`, `hakula-linux`, `hakula-devvm-docker`).

Successful builds are uploaded to the `hakula` Cachix cache on `main` or when the actor is `hakula139`.

> `statix.toml` suppresses W20 `repeated_keys`, since the flat-key style is intentional.

## Code Style

### Nix

- **Formatter**: `nixfmt` (enforced by pre-commit)
- **Linting**: `statix` and `deadnix` (enforced in CI)
- **Line width**: Default (100 characters)
- **Import style**: Use `with pkgs;` in package lists for brevity
- **`inherit` placement**: In `let` blocks, place `inherit` statements at the top (like imports). Combine multiple bindings from the same source: `inherit (pkgs.stdenv) isDarwin isLinux;`. In attribute sets, keep `inherit` in its logical position (e.g., `group` between `owner` and `path`)
- **Module structure**: Follow existing module patterns (enable option, config block, documentation strings)
- **Comments**: Only add when needed; avoid verbose / obvious comments (prefer clarity in naming / structure)

### Bash Scripts

- Multi-line formatting for complex commands (`if` / `else`, multi-argument `printf`, process substitutions)
- Descriptive variable names over terse ones

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
nix build '.#homeConfigurations.hakula-linux.activationPackage'
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

1. Add `secrets` parameter to the module's function signature if the module needs helper paths
2. Declare the secret using the helper library:
   - **NixOS**: `age.secrets.<attr> = secrets.mkSecret { name = "<service>/<secret>"; owner = "..."; group = "..."; };`
   - **Home Manager**: `hakula.secrets.required."<service>/<secret>" = { };`
3. Register the recipient list in `secrets/secrets.nix` and create the encrypted file: `cd secrets && agenix -e <service>/<secret>.age`
4. Reference Home Manager secrets through `config.hakula.secrets.path "<service>/<secret>"`, or set `path` only when a tool requires a fixed destination
5. Optional: override `mode` or `path` for custom permissions or location

## Proxy Configuration

Some hosts route Claude Code, Codex, and other LLM assistants through an **HTTP proxy**. This is configured per-host via `hakula.llm-assistants.proxy.*` in the host's `default.nix`, which fans out to the individual assistants (`claude-code`, `codex`, `opencode`). The proxy URL defaults to `http://127.0.0.1:7897` (local mihomo) but can be overridden via `url` or loaded from an agenix secret via `secretUrlFile`. Currently enabled on:

- `hakula-macbook`
- `hakula-linux`
- `hakula-devvm` (via `secretUrlFile`)

When working with network operations on these hosts, be aware that tools may route through this proxy.
