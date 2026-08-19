# Architecture

A flake-based NixOS / nix-darwin / system-manager configuration. `flake.nix` is the manifest: it holds inputs, special args, host registration, and outputs. Every host registers through one of the five `mk*` builders in `lib/builders.nix`.

## Hosts

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
│   ├── servers/                     # NixOS servers (us-1..us-4, sg-1) — all personal
│   ├── workstations/
│   │   ├── personal/                # macbook (Darwin)
│   │   └── work/                    # wsl (NixOS-WSL), wsl-non-nixos (System Manager)
│   └── images/                      # Buildable images (devvm — work)
├── data/                            # Static configuration and inventory
│   ├── caches.nix                   # Binary cache substituters and trusted public keys
│   ├── corp-domain.nix              # Corp-internal domain placeholder (gitignored real value)
│   ├── corp-hosts.nix               # Corp-internal hostnames and URLs
│   ├── servers.nix                  # Server inventory (IP, port, provider, host keys, builder config)
│   └── system-manager.nix           # Runtime PATH entries provisioned by system-manager activation
├── lib/                             # Pure helpers and framework code
│   ├── builders.nix                 # mkDarwin, mkDocker, mkHomeManagerConfig, mkServer, mkSystemManager, mkWSL
│   ├── overlays.nix                 # nixpkgs overlay (channels, flake-input CLIs, upstream overrides, custom packages)
│   ├── proxy.nix                    # mkProxyOptions, mkProxyScript, wrapWithProxy, no_proxy rendering
│   ├── secrets.nix                  # mkSecret, mkRequiredUserSecrets, secretFile, secretPath
│   ├── systemd.nix                  # Shared systemd unit hardening defaults
│   ├── tooling.nix                  # Shared tool groups (nix, secrets, shell, all)
│   ├── llm-assistants/              # Shared LLM-assistant helpers (mcpOptions, proxy, claude profile sets)
│   └── wsl/                         # Windows interop helpers (windows-interop.nu)
├── modules/
│   ├── shared.nix                   # Cross-platform primitives
│   ├── nixos/                       # NixOS service modules (most carry an `enable` option)
│   ├── darwin/                      # macOS-specific modules
│   └── system-manager/              # System Manager activation, agenix port
├── home/
│   ├── hakula.nix                   # Home Manager entry point
│   └── modules/                     # Home Manager modules (incl. `wsl.nix` workstation bundle)
├── packages/                        # Custom package definitions (callPackage targets in lib/overlays.nix)
├── secrets/                         # agenix-encrypted secrets and recipient rules
├── docs/                            # This knowledge base
└── .github/workflows/ci.yml         # CI pipeline
```

`hosts/_profiles/` splits into `platform/` for hardware or runtime shape and `role/` for server against workstation.
