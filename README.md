# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hakula139/nixos-config)

Flake-based Nix configuration for Hakula's servers, workstations, and development containers.

One flake manages five NixOS servers, three workstations (NixOS under WSL2, non-NixOS WSL through System Manager, and macOS through nix-darwin), and a NixOS Docker image for dev containers. It covers system configuration, Home Manager, custom packages, and agenix-encrypted secrets.

## Where to look

| Looking for                           | Read                                           |
| ------------------------------------- | ---------------------------------------------- |
| Supported hosts and repository layout | [Architecture](docs/reference/architecture.md) |
| First-time setup                      | [Bootstrap](docs/guides/bootstrap.md)          |
| Managing secrets                      | [Secrets](docs/guides/secrets.md)              |
| Changing the configuration            | [Contributor instructions](AGENTS.md)          |

## Applying a configuration

`nixsw` applies the current server or workstation configuration. The Home Manager zsh module substitutes the configured flake output name for `<config>` in these aliases:

| Alias     | NixOS                          | macOS                           | Generic Linux (System Manager)                        |
| --------- | ------------------------------ | ------------------------------- | ----------------------------------------------------- |
| `nixsw`   | `nh os switch '.#<config>'`    | `nh darwin switch '.#<config>'` | `system-manager switch ...` + post-switch healthcheck |
| `nixdp`   | `colmena apply`                | same                            | same                                                  |
| `nixlist` | NixOS generation list          | `darwin-rebuild` generations    | System Manager generation list                        |
| `nixroll` | `nixos-rebuild` rollback       | `darwin-rebuild` rollback       | System Manager rollback + reactivate + healthcheck    |
| `nixup`   | `nix flake update`             | same                            | same                                                  |
| `nixgc`   | `nh clean all --keep-since 3d` | same                            | same                                                  |

Deploy the servers by running `nixdp` from this repository, or target a single host with `nixdp --on us-4`. See [bootstrap](docs/guides/bootstrap.md#nixos-server) for prerequisites and host selection.

A machine with no managed configuration yet needs the bootstrap steps first, which differ per platform. The `devvm` container has no `nixsw` or `nixroll` alias. Apply its changes by [rebuilding the image](docs/guides/bootstrap.md#docker-image) and recreating the container.
