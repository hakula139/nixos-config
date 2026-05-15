# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **flake-based NixOS / nix-darwin configuration** managing multiple systems from a single declarative codebase:

- **5 NixOS servers** (us-1, us-2, us-3, us-4, sg-1) on x86_64-linux
- **1 macOS workstation** (hakula-macbook) on aarch64-darwin
- **1 generic Linux** (hakula-linux) using System Manager with Home Manager
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

# Generic Linux / Ubuntu WSL (after bootstrap)
system-manager switch --flake '.#hakula-linux' --sudo
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

# First-time generic Linux / Ubuntu WSL setup
nix run '.#system-manager' -- switch --flake '.#hakula-linux' --sudo
system-manager-health-check agenix-install-secrets.service home-manager-hakula.service
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
- `mkSystemManager`: Creates System Manager configurations for non-NixOS Linux, with agenix and Home Manager integrated
- `mkDocker`: Creates layered NixOS Docker images using `dockerTools.buildLayeredImageWithNixDb` for air-gapped deployment
- `overlays`: Provides `unstable` packages, `agenix` CLI, `system-manager`, custom packages (`cloudreve`, `mcp-server-*`), and a patched `peertube`
- `inputs.llm-agents`: Provides `claude-code` and `codex` packages from [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix)
- `forAllSystems`: Handles both x86_64-linux and aarch64-darwin

### Directory Layout

- `flake.nix` — main entry point. Outputs `nixosConfigurations`, `darwinConfigurations`, `systemConfigs`, `packages`, `colmena`, `checks`, `devShells`, `formatter`
- `hosts/` — per-host configurations. `hosts/_profiles/` holds reusable hardware / container profiles
- `modules/shared.nix` — cross-platform base config
- `modules/nixos/` — optional NixOS service modules (enabled per-host)
- `modules/darwin/` — macOS-specific modules
- `home/hakula.nix` + `home/modules/` — Home Manager user configuration
- `packages/` — custom package definitions
- `lib/` — shared helpers (`caches.nix`, `corp-domain.nix`, `secrets.nix`, `servers.nix`, `tooling.nix`, plus `llm-assistants/` for assistant-specific helpers and Claude profile sets)
- `secrets/` — agenix-encrypted secrets (`keys.nix` for SSH public keys, `secrets.nix` for recipient mapping)
- `.github/workflows/ci.yml` — CI pipeline

### Module System

NixOS modules in `modules/nixos/` are typically optionally enabled services exporting an `enable` option. Host configurations import and enable them selectively. A few helpers (`dockerhub`, etc.) export configuration options without an `enable` gate.

The `llm-assistants` module acts as an integration layer for the primary interactive user, nesting a `claude-code` sub-module that propagates assistant defaults down to Home Manager.

Home Manager modules in `home/modules/` configure user environments. The `isNixOS` and `isDesktop` flags drive conditional configuration (e.g., NixOS vs. System Manager, desktop vs. server).

### Shared Configuration Pattern

`modules/shared.nix` exports **cross-platform primitives**:

- `sshKeys`: User SSH public keys from `secrets/keys.nix`
- `basePackages`: Minimal system packages (curl, dig, git, htop, vim, wget)
- `fonts`: Maple Mono NF CN, Nerd Fonts, Sarasa Gothic, Source Han Sans/Serif
- `binaryCaches`: Binary cache substituters and public keys from `lib/caches.nix`
- `nixTooling`: Development tools from `lib/tooling.nix`
- `nixSettings`: Experimental features, buffer sizes
- `servers`: Server inventory imported from `lib/servers.nix` (IP, port, provider, host keys, builder config)

Host configurations import `shared.nix` and extend with platform/host-specific settings.

### Secrets with agenix

Secrets are encrypted with **age** using SSH keys declared in `secrets/keys.nix` (grouped as `users` / `hosts` / `workstations`). Recipient rules live in `secrets/secrets.nix`.

Secrets live in `secrets/` nested by service (e.g., `secrets/llm-assistants/claude-oauth-token.age`, `secrets/peertube/env.age`). They are **decrypted at activation time** by agenix. System-owned secrets (services, daemons) are referenced through `config.age.secrets.<attr-name>.path`. User-owned secrets declared via `hakula.secrets.required` are resolved through the `secretPath` module argument (see below).

#### Secrets Helper Library (`lib/secrets.nix`)

All platform modules materialize secrets through `age.secrets`. The two live helpers are:

- `mkSecret { name, owner ? "root", group ? owner, mode ? "0400", path ? null, file ? secretFile name }` — direct platform secret declaration. Used by NixOS / Darwin / system-manager modules that own a secret directly.
- `mkRequiredUserSecrets { homeConfig, userConfig, group ? null }` — collects entries from `homeConfig.hakula.secrets.required` and lifts them into `age.secrets`. Owner defaults to `userConfig.name`. Group falls back to the explicit `group` arg, then `userConfig.group`, then the owner.

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

The requirement attr name is the logical key. The attrset accepts optional `name` (encrypted source path, defaulting to the logical key) and `path` (decrypted destination, defaulting to `/run/agenix/<key>`). Override `name` when the consumer's logical key differs from the encrypted file:

```nix
hakula.secrets.required.github-pat.name = "github/pat-work";
```

Override `path` only when a tool requires a fixed destination:

```nix
hakula.secrets.required."wakatime/config".path = "${config.home.homeDirectory}/.wakatime.cfg";
```

Resolve a declared user secret to its decrypted runtime path through the `secretPath` module argument:

```nix
{ secretPath, ... }: {
  myService.tokenFile = secretPath "my-service/my-secret";
}
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
- **Comments**: Only add when needed. Avoid verbose / obvious comments and prefer clarity in naming / structure

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
nix build '.#systemConfigs.hakula-linux'
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
2. Accept `{ config, pkgs, lib, ... }`. Branch on `pkgs.stdenv.{isDarwin, isLinux}` for platform-specific config. Thread `isNixOS` / `isDesktop` only when the host builders set them.
3. Use `lib.mkIf` for conditional activation
4. Import in `home/hakula.nix`

### Adding a Custom Package

1. Create `packages/my-package/default.nix`
2. Follow standard Nix package structure (`stdenv.mkDerivation` or `buildGoModule`, etc.)
3. Add to `overlays` in `flake.nix`: `my-package = final.callPackage ./packages/my-package { };`
4. Reference as `pkgs.my-package` in modules

### Adding a Host

1. Create `hosts/my-host/default.nix` with host-specific configuration
2. Add to `nixosConfigurations`, `darwinConfigurations`, or `systemConfigs` in `flake.nix` using the appropriate builder (`mkServer`, `mkDarwin`, or `mkSystemManager`)
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

1. Declare the secret using the helper library:
   - **NixOS / Darwin / system-manager**: `age.secrets.<attr> = secrets.mkSecret { name = "<service>/<secret>"; owner = "..."; group = "..."; };`
   - **Home Manager**: `hakula.secrets.required."<service>/<secret>" = { };`
2. Register the recipient list in `secrets/secrets.nix` and create the encrypted file: `cd secrets && agenix -e <service>/<secret>.age`
3. Reference Home Manager secrets through the `secretPath` module argument: `secretPath "<service>/<secret>"`. Set `name` to override the encrypted source path, or `path` only when a tool requires a fixed destination.

## Proxy Configuration

Some hosts route Claude Code, Codex, and other LLM assistants through an **HTTP proxy**. Configured per-host via `hakula.llm-assistants.proxy.*`, which fans out to the individual assistants (`claude-code`, `codex`, `opencode`). The proxy URL defaults to `http://127.0.0.1:7897` (local mihomo) but can be overridden via `url` or loaded from an agenix secret via `secretUrlFile`. Currently enabled on:

- `hakula-macbook` — set at the Darwin module level
- `hakula-linux` — set in the host's Home Manager block (under `home-manager.users.<primary-user>.hakula.llm-assistants`)
- `hakula-devvm` — set under `home-manager.users.root.hakula.llm-assistants`, sourced from `secretUrlFile`

When working with network operations on these hosts, be aware that tools may route through this proxy.
