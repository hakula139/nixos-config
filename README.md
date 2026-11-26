# Nix Configuration

[![CI](https://github.com/hakulab/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakulab/nixos-config/actions/workflows/ci.yml)
![WakaTime coding time for nixos-config](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/7afcb821-4d64-4db6-ab32-b0e0ee8a29cb.svg)

Personal Nix configuration for NixOS servers, WSL workstations, macOS, and development containers. A shared flake manages system configuration, Home Manager, custom packages, and sops-nix secrets.

## Applying a configuration

Run `nixsw` from the repository root to apply the local configuration, and `nixdp` to deploy NixOS servers. See [Deployment] for targeting flags and server deployment rules.

## Documentation

| Document                   | Description                                     |
| -------------------------- | ----------------------------------------------- |
| [Bootstrap]                | First-time installation and Docker image builds |
| [Deployment]               | Applying configurations and deploying servers   |
| [Architecture]             | Supported hosts and repository layout           |
| [Agent company]            | Parallel project teams and agent delegation     |
| [Secrets]                  | Managing encrypted credentials                  |
| [Contributor instructions] | Conventions and verification for changes        |

[Bootstrap]: docs/guides/bootstrap.md
[Deployment]: docs/guides/deployment.md
[Architecture]: docs/reference/architecture.md
[Agent company]: docs/reference/agent-company.md
[Secrets]: .agents/skills/sops/SKILL.md
[Contributor instructions]: AGENTS.md
