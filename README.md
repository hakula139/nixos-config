# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hakula139/nixos-config)

Flake-based Nix configuration for Hakula's servers, workstations, and development containers.

## Overview

This repository manages NixOS, nix-darwin, System Manager, Home Manager, custom packages, encrypted secrets, and deployable development images from one flake.

| Output                                      | Platform         | Role                                  |
| ------------------------------------------- | ---------------- | ------------------------------------- |
| `nixosConfigurations.us-1`                  | `x86_64-linux`   | NixOS server, CloudCone SC2           |
| `nixosConfigurations.us-2`                  | `x86_64-linux`   | NixOS server, CloudCone VPS           |
| `nixosConfigurations.us-3`                  | `x86_64-linux`   | NixOS server, CloudCone SC2           |
| `nixosConfigurations.us-4`                  | `x86_64-linux`   | NixOS server, DMIT                    |
| `nixosConfigurations.sg-1`                  | `x86_64-linux`   | NixOS server, Tencent Lighthouse      |
| `darwinConfigurations.hakula-macbook`       | `aarch64-darwin` | macOS workstation with nix-darwin     |
| `systemConfigs.hakula-linux`                | `x86_64-linux`   | Generic Linux with System Manager     |
| `packages.x86_64-linux.hakula-devvm-docker` | `x86_64-linux`   | NixOS Docker image for dev containers |

## Layout

```text
.
├── flake.nix                        # Inputs, special args, host registration, outputs
├── hosts/                           # Per-host configurations
│   └── _profiles/                   # Reusable hardware / container profiles
├── modules/
│   ├── shared.nix                   # Cross-platform primitives
│   ├── nixos/                       # NixOS service modules
│   ├── darwin/                      # macOS-specific modules
│   └── system-manager/              # System Manager activation, agenix port
├── home/
│   ├── hakula.nix                   # Home Manager entry point
│   └── modules/                     # Home Manager modules
├── lib/                             # Helpers (overlays, builders, caches, secrets, servers, tooling)
├── packages/                        # Custom package definitions
├── secrets/                         # agenix-encrypted secrets and recipient rules
└── .github/workflows/ci.yml         # CI pipeline
```

## Usage

### NixOS Servers

Bootstrap a new server with `nixos-anywhere`:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>
```

Apply on a server:

```bash
nh os switch .
```

Deploy from a workstation with Colmena:

```bash
colmena apply                  # all servers
colmena apply --on us-4        # one server
colmena apply --on @cloudcone  # provider tag
```

Server inventory and deployment metadata live in `lib/servers.nix`.

### macOS

Install Nix with Determinate Nix Installer:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Bootstrap nix-darwin:

```bash
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#hakula-macbook'
```

Apply after bootstrap:

```bash
nh darwin switch .
```

### Generic Linux

`hakula-linux` uses [system-manager](https://github.com/numtide/system-manager) to own the system profile, user shell integration, agenix secret activation, and Home Manager activation service.

Install Nix with Determinate Nix Installer:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Bootstrap System Manager before the managed profile installs `system-manager` itself:

```bash
nix run '.#system-manager' -- switch --flake '.#hakula-linux' --sudo
system-manager-health-check agenix-install-secrets.service home-manager-hakula.service
```

Apply after bootstrap:

```bash
system-manager switch --flake '.#hakula-linux' --sudo
```

### Docker Image

Build the air-gapped development image:

```bash
nix build '.#packages.x86_64-linux.hakula-devvm-docker'
```

Load and start it:

```bash
docker load < result
docker compose -f hosts/hakula-devvm/docker-compose.yml up -d
```

Attach with the VS Code / Cursor Dev Containers command.

### Shell Aliases

The Home Manager zsh module ships matching aliases on every platform:

| Alias     | NixOS                          | macOS                        | Generic Linux (System Manager)                        |
| --------- | ------------------------------ | ---------------------------- | ----------------------------------------------------- |
| `nixsw`   | `nh os switch .`               | `nh darwin switch .`         | `system-manager switch ...` + post-switch healthcheck |
| `nixlist` | NixOS generation list          | `darwin-rebuild` generations | System Manager generation list                        |
| `nixroll` | `nixos-rebuild` rollback       | `darwin-rebuild` rollback    | System Manager rollback + reactivate + healthcheck    |
| `nixup`   | `nix flake update`             | same                         | same                                                  |
| `nixgc`   | `nh clean all --keep-since 7d` | same                         | same                                                  |

## Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). Home Manager modules declare requirements through `hakula.secrets.required`, and each platform's system module materializes them as `age.secrets`. See `lib/secrets.nix` for the helper API and `CLAUDE.md` for the recipe.

```bash
cd secrets
agenix -e <service>/<name>.age -i ~/.ssh/<private-key>  # Edit
agenix -r -i ~/.ssh/<private-key>                       # Re-key after changing recipients
```

Run `agenix -r` from an interactive terminal — see `CLAUDE.md` for the gotcha.

## Development

```bash
nix develop -c zsh                                      # Enter the development shell
nix flake update                                        # Update inputs
git ls-files '*.nix' -z | xargs -0 nix fmt              # Format Nix files
nix flake check                                         # Run CI-style validation
```

Build representative targets:

```bash
nix build '.#nixosConfigurations.us-4.config.system.build.toplevel'
nix build '.#darwinConfigurations.hakula-macbook.system'
nix build '.#systemConfigs.hakula-linux'
nix build '.#packages.x86_64-linux.hakula-devvm-docker'
```

## CI

GitHub Actions runs on every push and pull request:

- **Flake Check**: `nix flake check --all-systems` — flake structure and pre-commit hooks (`nixfmt`, `statix`, `deadnix`, `check-added-large-files`, `check-yaml`, `end-of-file-fixer`, `trim-trailing-whitespace`).
- **Build NixOS**: builds the five server configurations (`us-1`, `us-2`, `us-3`, `us-4`, `sg-1`) on `ubuntu-latest`.
- **Build macOS**: builds `hakula-macbook` on `macos-latest`, then pins `peertube-runner` to the Cachix cache.
- **Build Generic Linux**: builds `systemConfigs.hakula-linux` on `ubuntu-latest`.
- **Build Docker**: builds `hakula-devvm-docker` on `ubuntu-latest`.
- **Closure size check**: prints `nix path-info -Sh` for each built target.
