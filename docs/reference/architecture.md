# Architecture

A flake-based NixOS / nix-darwin / system-manager configuration. Every host registers through one of the five `mk*` builders in `lib/builders.nix`.

## Hosts

| Output                               | Platform         | Role                                                |
| ------------------------------------ | ---------------- | --------------------------------------------------- |
| `nixosConfigurations.us-1`           | `x86_64-linux`   | NixOS server, CloudCone SC2                         |
| `nixosConfigurations.us-4`           | `x86_64-linux`   | NixOS server, DMIT                                  |
| `nixosConfigurations.wsl`            | `x86_64-linux`   | NixOS-WSL workstation                               |
| `systemConfigs.wsl-non-nixos`        | `x86_64-linux`   | Non-NixOS WSL workstation managed by System Manager |
| `darwinConfigurations.macbook`       | `aarch64-darwin` | macOS workstation with nix-darwin                   |
| `packages.x86_64-linux.devvm-docker` | `x86_64-linux`   | NixOS Docker image for dev containers               |

## Layout

```text
.
├── flake.nix                       # Inputs, special args, host registration, outputs
├── hosts/
│   ├── _profiles/
│   │   ├── platform/               # Hardware / runtime shape (cloudcone-sc2, container, wsl, ...)
│   │   └── role/                   # Server or workstation role
│   ├── servers/                    # NixOS servers (us-1, us-4), all personal
│   ├── workstations/
│   │   ├── personal/               # macbook (Darwin)
│   │   └── work/                   # wsl (NixOS-WSL), wsl-non-nixos (System Manager)
│   └── images/                     # Buildable images (devvm)
├── data/                           # Static configuration and inventory
│   ├── default.nix                 # Index of shared data sets passed as special args
│   ├── backblaze.nix               # Backblaze B2 S3 endpoint
│   ├── caches.nix                  # Binary cache URLs and public keys by name
│   ├── corp-domain.nix             # Corp-internal domain
│   ├── corp-hosts.nix              # Corp-internal hostnames and URLs
│   ├── llm-models.nix              # Shared model catalog and defaults
│   ├── platform-settings.nix       # Cross-platform locale, time zone, Nix, and GC settings
│   ├── servers.nix                 # Server inventory (IP, port, provider, host keys, builders)
│   ├── ssh.nix                     # SSH port shared by every sshd and client entry
│   └── system-manager-paths.nix    # PATH entries provisioned by system-manager activation
├── lib/                            # Pure helpers and framework code
│   ├── default.nix                 # Repository helper namespace exposed as repoLib
│   ├── aria2.nix                   # Shared aria2 download and RPC settings
│   ├── builders.nix                # mk* host builders
│   ├── dev-shells.nix              # `devShells.<system>`, the default and browser shells
│   ├── overlays.nix                # nixpkgs overlay (channels, CLIs, toolchains, custom packages)
│   ├── packages.nix                # Base and font package groups for each package set
│   ├── pre-commit.nix              # Shared devkit hook configuration
│   ├── proxy.nix                   # Proxy options, wrappers, and environment scripts
│   ├── secrets.nix                 # Secret declarations and path helpers
│   ├── ssh.nix                     # Builder and SSH configuration from server inventory
│   ├── systemd.nix                 # Shared systemd hardening and restart policies
│   ├── tooling.nix                 # Shared development tool groups
│   ├── wrap-package.nix            # Package wrappers preserving upstream launcher identity
│   ├── llm-assistants/             # Assistant options, permissions, and profiles
│   ├── mihomo/                     # Shared mihomo settings, update / start / port-check commands
│   ├── nu/                         # Shared Nushell modules (`*.nu`) and test helpers (`*.testlib.nu`)
│   ├── nu-command/                 # Nushell command adapter over devkit
│   └── wsl/                        # Windows interop helpers (windows-interop.nu)
├── modules/
│   ├── darwin/                     # macOS-specific modules
│   ├── nixos/                      # NixOS service modules (most carry an `enable` option)
│   ├── shared/                     # Modules imported by more than one tree
│   └── system-manager/             # System Manager activation, agenix port
├── home/
│   ├── hakula.nix                  # Home Manager entry point
│   └── modules/                    # Home Manager modules (incl. `wsl.nix` workstation bundle)
├── packages/                       # Custom package definitions called by lib/overlays.nix
├── secrets/                        # agenix-encrypted secrets and recipient rules
├── tests/                          # `checks.<system>`, one aggregator over per-case directories
│   ├── default.nix                 # Aggregator importing each check case
│   ├── nu-command/                 # Nushell command adapter check with its fixtures
│   └── scripts/                    # `checks.<system>.scripts`, nu-test and bun tests
├── agenix-rules.nix                # Root-level agenix entry point for recipient rules
├── docs/                           # This knowledge base
└── .github/workflows/ci.yml        # CI pipeline
```
