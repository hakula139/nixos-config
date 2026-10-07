# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
![WakaTime coding time for nixos-config](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/7afcb821-4d64-4db6-ab32-b0e0ee8a29cb.svg)

Personal Nix configuration for NixOS servers, WSL workstations, macOS, and development containers. A shared flake manages system configuration, Home Manager, custom packages, and agenix-encrypted secrets.

## Applying a configuration

After initial setup, use `nixsw` to apply the local server or workstation configuration. Run it from the repository root in the managed Zsh environment.

Deploy all servers with `nixdp`, or select a host:

```bash
nixdp --on us-4
```

## Documentation

- [Bootstrap](docs/guides/bootstrap.md): First-time installation and Docker image builds.
- [Architecture](docs/reference/architecture.md): Supported hosts and repository layout.
- [Secrets](docs/guides/secrets.md): Managing encrypted credentials.
- [Contributor instructions](AGENTS.md): Conventions and verification for configuration changes.
