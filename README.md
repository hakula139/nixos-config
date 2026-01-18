# NixOS Configuration

[![CI](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/nixos-config/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hakula139/nixos-config)

NixOS configuration for Hakula's machines (flake-based).

## Hosts

| Host             | System         | Type                         |
| ---------------- | -------------- | ---------------------------- |
| `us-1`           | x86_64-linux   | NixOS server                 |
| `us-2`           | x86_64-linux   | NixOS server                 |
| `us-3`           | x86_64-linux   | NixOS server                 |
| `sg-1`           | x86_64-linux   | NixOS server                 |
| `hakula-macbook` | aarch64-darwin | macOS (nix-darwin)           |
| `hakula-work`    | x86_64-linux   | Generic Linux (Home Manager) |

## NixOS

### Prerequisites (NixOS)

Install NixOS with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere):

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>
```

### Apply NixOS Configuration

```bash
sudo nixos-rebuild switch --flake '.#us-1'
```

After setting up the alias:

```bash
nixsw us-1
```

## macOS

### Prerequisites (macOS)

Install Nix with [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Bootstrap with [nix-darwin](https://github.com/LnL7/nix-darwin) (first switch):

```bash
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#hakula-macbook'
```

### Apply Darwin Configuration

```bash
sudo darwin-rebuild switch --flake '.#hakula-macbook'
```

After setting up the alias:

```bash
nixsw hakula-macbook
```

## Home Manager (standalone, for non-NixOS Linux)

### Prerequisites (Nix)

Install Nix with [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

### Apply Home Manager Configuration

```bash
nix run home-manager -- switch --flake '.#hakula-work'
```

If Home Manager is installed globally:

```bash
home-manager switch --flake '.#hakula-work'
```

After setting up the alias:

```bash
nixsw hakula-work
```

## Update

```bash
nix flake update
```

## Formatting

This repository uses [nixfmt-rfc-style](https://github.com/NixOS/nixfmt). Format all Nix files with:

```bash
git ls-files '*.nix' -z | xargs -0 nix fmt
```

## Pre-commit

This repository uses a Nix-native pre-commit setup (via `git-hooks.nix`).

Enable hooks locally (installs into `.git/hooks`):

```bash
nix develop -c zsh
```

CI-style check (does not modify your working tree; fails if formatting would change files):

```bash
nix flake check
```

## Continuous Integration

GitHub Actions automatically validates the configuration on every push and pull request:

- **Flake Check**: Validates flake structure using `nix flake check --all-systems`
- **Build NixOS**: Tests building the `us-1` NixOS server configuration on x86_64-linux
- **Build Generic Linux**: Tests building the `hakula-work` Home Manager configuration on x86_64-linux
- **Build macOS**: Tests building the `hakula-macbook` configuration on aarch64-darwin

## Secrets

Secrets are managed with [agenix](https://github.com/ryantm/agenix). Edit secrets with:

```bash
cd secrets
agenix -e <secret-name>.age -i ~/.ssh/<private-key>
```
