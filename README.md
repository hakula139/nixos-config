# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
![WakaTime coding time for nixos-config](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/7afcb821-4d64-4db6-ab32-b0e0ee8a29cb.svg)

Personal Nix configuration for NixOS servers, WSL workstations, macOS, and development containers. A shared flake manages system configuration, Home Manager, custom packages, and agenix-encrypted secrets.

## Applying a configuration

After initial setup, run `nixsw` from the repository root in the managed Zsh environment to apply the local configuration. `nixdp` aliases `colmena apply` and accepts its flags: `nixdp` deploys every server, and `nixdp --on us-4` or `nixdp --on @cloudcone` selects hosts.

Every proxy node in `data/servers.nix` is a deploy target, and activating one can restart its nginx or Xray, cutting off an SSH session routed through it. Switch the workstation's proxy client to another node before deploying a node. When proxy credentials rotate, deploy the subscription host `us-4` first through a node not yet deployed, then refresh the client's subscription before deploying the rest.

## Documentation

- [Bootstrap](docs/guides/bootstrap.md): First-time installation and Docker image builds.
- [Architecture](docs/reference/architecture.md): Supported hosts and repository layout.
- [Secrets](docs/guides/secrets.md): Managing encrypted credentials.
- [Contributor instructions](AGENTS.md): Conventions and verification for configuration changes.
