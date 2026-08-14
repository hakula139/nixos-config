# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hakula139/nixos-config)

Flake-based Nix configuration for Hakula's servers, workstations, and development containers.

## Overview

This repository manages NixOS, nix-darwin, System Manager, Home Manager, custom packages, encrypted secrets, and deployable development images from one flake.

| Output                               | Platform         | Role                                                |
| ------------------------------------ | ---------------- | --------------------------------------------------- |
| `nixosConfigurations.us-1`           | `x86_64-linux`   | NixOS server, CloudCone SC2                         |
| `nixosConfigurations.us-2`           | `x86_64-linux`   | NixOS server, CloudCone VPS                         |
| `nixosConfigurations.us-3`           | `x86_64-linux`   | NixOS server, CloudCone SC2                         |
| `nixosConfigurations.us-4`           | `x86_64-linux`   | NixOS server, DMIT                                  |
| `nixosConfigurations.sg-1`           | `x86_64-linux`   | NixOS server, Tencent Lighthouse                    |
| `nixosConfigurations.wsl`            | `x86_64-linux`   | NixOS-WSL workstation                               |
| `systemConfigs.wsl-non-nixos`        | `x86_64-linux`   | Non-NixOS WSL workstation managed by System Manager |
| `darwinConfigurations.macbook`       | `aarch64-darwin` | macOS workstation with nix-darwin                   |
| `packages.x86_64-linux.devvm-docker` | `x86_64-linux`   | NixOS Docker image for dev containers               |

## Layout

```text
.
├── flake.nix                        # Inputs, special args, host registration, outputs
├── hosts/
│   ├── _profiles/
│   │   ├── platform/                # Hardware / runtime shape (cloudcone-sc2, container, wsl, ...)
│   │   └── role/                    # System role (server, workstation)
│   ├── servers/                     # NixOS servers (us-1..us-4, sg-1)
│   ├── workstations/                # wsl (NixOS-WSL), wsl-non-nixos (System Manager), macbook (Darwin)
│   └── images/                      # Buildable images (devvm)
├── modules/
│   ├── shared.nix                   # Cross-platform primitives
│   ├── nixos/                       # NixOS service modules
│   ├── darwin/                      # macOS-specific modules
│   └── system-manager/              # System Manager activation, agenix port
├── home/
│   ├── hakula.nix                   # Home Manager entry point
│   └── modules/                     # Home Manager modules (incl. wsl.nix bundle)
├── lib/                             # Helpers (overlays, builders, secrets, proxy, tooling, ...)
├── packages/                        # Custom package definitions
├── secrets/                         # agenix-encrypted secrets and recipient rules
└── .github/workflows/ci.yml         # CI pipeline
```

## Usage

After bootstrap, apply the current host configuration with the platform-aware zsh alias:

```bash
nixsw
```

### NixOS Servers

Bootstrap a new server with `nixos-anywhere`:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>
```

Deploy from a workstation with Colmena:

```bash
colmena apply                                           # all servers
colmena apply --on us-4                                 # one server
colmena apply --on @cloudcone                           # provider tag
```

Server inventory and deployment metadata live in `data/servers.nix`.

### NixOS-WSL Workstation

`wsl` is a full NixOS workstation running under Microsoft WSL2 via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL).

Build the import tarball from any host with the flake checked out:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
sudo ./result/bin/nixos-wsl-tarball-builder             # produces ./nixos.wsl
```

Move `nixos.wsl` to the Windows side and import (PowerShell):

```powershell
wsl --shutdown
wsl --install --from-file .\nixos.wsl                   # WSL ≥ 2.4.4
wsl -d NixOS                                            # first launch
```

On older WSL versions, import with `wsl --import NixOS C:\WSL\NixOS .\nixos.wsl`.

Inside the new distro, copy the agenix identity from the Windows side and apply the managed configuration:

```bash
git clone https://github.com/hakula139/nixos-config ~/nixos-config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp /mnt/c/Users/<name>/.ssh/id_ed25519     ~/.ssh/id_ed25519
cp /mnt/c/Users/<name>/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/id_ed25519

sudo nixos-rebuild switch --flake ~/nixos-config#wsl
```

### Non-NixOS Linux (System Manager)

`wsl-non-nixos` uses [system-manager](https://github.com/numtide/system-manager) to own the system profile, user shell integration, agenix secret activation, and Home Manager activation service. It is the WSL workstation for non-NixOS Linux distros.

Install Nix with Determinate Nix Installer:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Bootstrap System Manager before the managed profile installs `system-manager` itself:

```bash
nix run '.#system-manager' -- switch --flake '.#wsl-non-nixos' --sudo
system-manager-health-check agenix-install-secrets.service home-manager-hakula.service
```

### macOS

Install Nix with Determinate Nix Installer:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Bootstrap nix-darwin:

```bash
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake '.#macbook'
```

### Docker Image

Build the air-gapped development image:

```bash
nix build '.#packages.x86_64-linux.devvm-docker'
```

Load and start it:

```bash
docker load < result
docker compose -f hosts/images/devvm/docker-compose.yml up -d
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
| `nixgc`   | `nh clean all --keep-since 3d` | same                         | same                                                  |

## Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). Home Manager modules declare requirements through `hakula.secrets.required`, and each platform's system module materializes them as `age.secrets`. See `lib/secrets.nix` for the helper API and `CLAUDE.md` for the recipe.

```bash
cd secrets
agenix -e <service>/<name>.age -i ~/.ssh/<private-key>  # Edit
agenix -r -i ~/.ssh/<private-key>                       # Re-key after changing recipients
```

Run `agenix -r` from an interactive terminal. See `CLAUDE.md` for the TTY caveat.

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
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#darwinConfigurations.macbook.system'
nix build '.#packages.x86_64-linux.devvm-docker'
```

## CI

GitHub Actions runs on every push and pull request:

- **Flake Check**: `nix flake check --all-systems` for flake structure and pre-commit hooks (`cspell`, `deadnix`, `markdownlint`, `nixfmt`, `statix`, `check-added-large-files`, `check-yaml`, `end-of-file-fixer`, `trim-trailing-whitespace`).
- **Build NixOS**: builds the five server configurations (`us-1`, `us-2`, `us-3`, `us-4`, `sg-1`) on `ubuntu-latest`.
- **Build NixOS-WSL**: builds `wsl` on `ubuntu-latest`.
- **Build WSL (non-NixOS)**: builds `systemConfigs.wsl-non-nixos` on `ubuntu-latest`.
- **Build macOS**: builds `macbook` on `macos-latest`, then pins `peertube-runner` to the Cachix cache.
- **Build Docker**: builds `devvm-docker` on `ubuntu-latest`.
- **Closure size check**: prints `nix path-info -Sh` for each built target.
