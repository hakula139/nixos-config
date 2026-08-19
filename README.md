# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hakula139/nixos-config)

Flake-based Nix configuration for Hakula's servers, workstations, and development containers.

One flake manages five NixOS servers, three workstations (NixOS under WSL2, non-NixOS WSL through System Manager, and macOS through nix-darwin), and a NixOS Docker image for dev containers. It covers system configuration, Home Manager, custom packages, and agenix-encrypted secrets.

## Where to look

| Looking for                                | Read                                                             |
| ------------------------------------------ | ---------------------------------------------------------------- |
| First-time setup on any platform           | [docs/guides/bootstrap.md](docs/guides/bootstrap.md)             |
| The host inventory and how hosts are wired | [docs/reference/architecture.md](docs/reference/architecture.md) |
| Editing or re-keying a secret              | [docs/guides/secrets.md](docs/guides/secrets.md)                 |
| Assistant proxy configuration              | [docs/reference/proxy.md](docs/reference/proxy.md)               |
| What CI checks on every push               | [docs/reference/ci.md](docs/reference/ci.md)                     |
| Coding conventions                         | [docs/conventions/](docs/conventions/)                           |
| Changing the code with a coding assistant  | [AGENTS.md](AGENTS.md)                                           |

## Applying a configuration

`nixsw` applies the current host's configuration on every platform. The Home Manager zsh module ships a matching set of aliases:

| Alias     | NixOS                          | macOS                        | Generic Linux (System Manager)                        |
| --------- | ------------------------------ | ---------------------------- | ----------------------------------------------------- |
| `nixsw`   | `nh os switch .`               | `nh darwin switch .`         | `system-manager switch ...` + post-switch healthcheck |
| `nixlist` | NixOS generation list          | `darwin-rebuild` generations | System Manager generation list                        |
| `nixroll` | `nixos-rebuild` rollback       | `darwin-rebuild` rollback    | System Manager rollback + reactivate + healthcheck    |
| `nixup`   | `nix flake update`             | same                         | same                                                  |
| `nixgc`   | `nh clean all --keep-since 3d` | same                         | same                                                  |

A machine with no managed configuration yet needs the bootstrap steps first, which differ per platform.

## Development

```bash
nix develop -c zsh                                      # Enter the development shell
nix flake check                                         # Run CI-style validation
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
```
