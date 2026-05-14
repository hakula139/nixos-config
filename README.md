# Nix Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hakula139/nixos-config)

Flake-based Nix configuration for Hakula's servers, workstations, and development containers.

## Overview

This repository manages NixOS, nix-darwin, System Manager, Home Manager, custom packages, encrypted secrets, and deployable development images from one flake.

| Output                                      | Platform         | Role                                           |
| ------------------------------------------- | ---------------- | ---------------------------------------------- |
| `nixosConfigurations.us-1`                  | `x86_64-linux`   | NixOS server, CloudCone SC2                    |
| `nixosConfigurations.us-2`                  | `x86_64-linux`   | NixOS server, CloudCone VPS                    |
| `nixosConfigurations.us-3`                  | `x86_64-linux`   | NixOS server, CloudCone SC2                    |
| `nixosConfigurations.us-4`                  | `x86_64-linux`   | NixOS server, DMIT                             |
| `nixosConfigurations.sg-1`                  | `x86_64-linux`   | NixOS server, Tencent Lighthouse               |
| `darwinConfigurations.hakula-macbook`       | `aarch64-darwin` | macOS workstation with nix-darwin              |
| `systemConfigs.hakula-linux`                | `x86_64-linux`   | Generic Linux / Ubuntu WSL with System Manager |
| `packages.x86_64-linux.hakula-devvm-docker` | `x86_64-linux`   | NixOS Docker image for dev containers          |

## Layout

- `flake.nix`: flake inputs, overlays, builders, and outputs
- `hosts/`: host-specific configuration and reusable host profiles
- `modules/`: NixOS, nix-darwin, and System Manager modules
- `home/`: Home Manager configuration and user modules
- `lib/`: shared helpers, inventories, cache settings, and tooling
- `packages/`: custom package definitions
- `secrets/`: agenix encrypted secrets and recipient rules

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

### Generic Linux / Ubuntu WSL

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

Shell aliases:

```bash
nixsw    # Switch, then check agenix and Home Manager services
nixlist  # List System Manager generations
nixroll  # Roll back the System Manager profile and reactivate it
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

## Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). Recipient rules are declared in `secrets/secrets.nix`, and encrypted files live under `secrets/` with paths matching their logical names.

Home Manager modules declare their secret requirements:

```nix
hakula.secrets.required = {
  "mihomo/secret" = { };
};
```

Consumers read the runtime path through the shared resolver:

```nix
config.hakula.secrets.path "mihomo/secret"
```

Use `name` only when the logical consumer key differs from the encrypted source:

```nix
hakula.secrets.required.github-pat = {
  name = "github/pat-work";
};
```

Use `path` only when a program requires a fixed destination:

```nix
hakula.secrets.required."wakatime/config" = {
  path = "${config.home.homeDirectory}/.wakatime.cfg";
};
```

Platform modules collect those requirements and materialize them with `age.secrets`, so Home Manager modules do not configure a second secret backend.

Edit a secret:

```bash
cd secrets
agenix -e <service>/<name>.age -i ~/.ssh/<private-key>
```

Re-key after changing recipients:

```bash
cd secrets
agenix -r -i ~/.ssh/<private-key>
```

Run `agenix -r` from an interactive terminal. In a non-interactive shell, agenix can replace secret contents with empty stdin before re-encrypting them.

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

GitHub Actions runs `nix flake check --all-systems`, then builds every managed system output. Successful builds are pushed to the `hakula` Cachix cache on `main` and when the actor is `hakula139`.
