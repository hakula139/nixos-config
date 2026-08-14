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

See [docs/reference/architecture.md](docs/reference/architecture.md) for the directory layout and how hosts are wired.

## Usage

Apply the current host configuration with the platform-aware zsh alias:

```bash
nixsw
```

First-time setup differs per platform, from `nixos-anywhere` on a fresh server to a WSL import tarball. [docs/guides/bootstrap.md](docs/guides/bootstrap.md) covers each one.

Multi-server deploys go through Colmena, where `--on` takes a host name or a provider tag:

```bash
colmena apply
colmena apply --on us-4
colmena apply --on @cloudcone
```

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

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). Home Manager modules declare requirements through `hakula.secrets.required`, and each platform's system module materializes them as `age.secrets`.

```bash
cd secrets
agenix -e <service>/<name>.age -i ~/.ssh/<private-key>  # Edit
agenix -r -i ~/.ssh/<private-key>                       # Re-key after changing recipients
```

Run `agenix -r` from an interactive terminal only. [docs/guides/secrets.md](docs/guides/secrets.md) explains why, along with the helper API and naming rules.

## Development

```bash
nix develop -c zsh                                      # Enter the development shell
nix flake update                                        # Update inputs
git ls-files '*.nix' -z | xargs -0 nix fmt              # Format Nix files
nix flake check                                         # Run CI-style validation
```

Build a representative target:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
```

Contributor conventions live under [docs/conventions/](docs/conventions/), and [AGENTS.md](AGENTS.md) indexes them for coding assistants.

## CI

GitHub Actions runs a flake check plus a parallel build of every host on each push and pull request. See [docs/reference/ci.md](docs/reference/ci.md).
