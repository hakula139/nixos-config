# CLAUDE.md: nixos-config

Guidance for Claude Code (claude.ai/code) when working in this repository. Follow `~/.claude/CLAUDE.md` for global communication, scope, comment, and commit doctrine. Sections here add project-specific rules only. Keep anything inferable from `flake.nix` or a representative module in the code.

## Repository Overview

A flake-based NixOS / nix-darwin / system-manager configuration:

- **5 NixOS servers** (us-1, us-2, us-3, us-4, sg-1) on x86_64-linux
- **1 NixOS-WSL workstation** (wsl) on x86_64-linux
- **1 system-manager workstation** (wsl-non-nixos) on x86_64-linux WSL atop a non-NixOS distro
- **1 macOS workstation** (macbook) on aarch64-darwin
- **1 Docker image** (devvm) for air-gapped deployment

`flake.nix` is the manifest. Builders live in `lib/builders.nix`, and overlays live in `lib/overlays.nix`. Per-host config lives in `hosts/`. Cross-platform primitives live in `modules/shared.nix`.

### Project Layout

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
│   ├── servers.nix                  # Server inventory (IP, port, provider, host keys, builder config)
│   └── system-manager.nix           # Runtime PATH entries provisioned by system-manager activation
├── lib/                             # Pure helpers and framework code
│   ├── builders.nix                 # mkDarwin, mkDocker, mkHomeManagerConfig, mkServer, mkSystemManager, mkWSL, serverSharedModules
│   ├── overlays.nix                 # nixpkgs overlay (channels, flake-input CLIs, upstream overrides, toolchains, custom packages)
│   ├── secrets.nix                  # mkSecret, mkRequiredUserSecrets, secretFile, secretPath
│   ├── tooling.nix                  # Dev shell tooling
│   └── llm-assistants/              # Shared LLM-assistant helpers (mcpOptions, proxy, claude profile sets)
├── modules/
│   ├── shared.nix                   # Cross-platform Home Manager primitives
│   ├── nixos/                       # NixOS service modules (most carry an `enable` option)
│   ├── darwin/                      # macOS-specific modules
│   └── system-manager/              # System Manager activation, agenix port
├── home/
│   ├── hakula.nix                   # Home Manager entry point
│   └── modules/                     # Home Manager modules (incl. `wsl.nix` workstation bundle)
├── packages/                        # Custom package definitions (callPackage targets in lib/overlays.nix)
├── secrets/                         # agenix-encrypted secrets and recipient rules
└── .github/workflows/ci.yml         # CI pipeline
```

## Bootstrap Commands

First-time setup is the workflow that's hard to infer. Day-to-day applies use the `nixsw` zsh alias on every platform.

```bash
# NixOS server
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>

# NixOS-WSL workstation: build the import tarball, then `wsl --install --from-file` on Windows
nix build '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
sudo ./result/bin/nixos-wsl-tarball-builder           # produces ./nixos.wsl

# Non-NixOS Linux (WSL workstation)
nix run '.#system-manager' -- switch --flake '.#wsl-non-nixos' --sudo
system-manager-health-check agenix-install-secrets.service home-manager-hakula.service

# macOS
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#macbook'
```

Multi-server deploys go through Colmena: `colmena apply --on us-4`, `colmena apply --on @cloudcone` for provider tags.

## Secrets

Two helpers in `lib/secrets.nix`, two contracts.

System-side (NixOS / Darwin / system-manager modules):

```nix
age.secrets.<attr> = secrets.mkSecret {
  name = "<service>/<secret>";
  owner = "...";
  group = "...";
};
```

User-side (Home Manager modules):

```nix
hakula.secrets.required."<service>/<secret>" = { };
```

Then resolve through the `secretPath` module argument: `secretPath "<service>/<secret>"`.

Decrypted runtime paths mirror the `secrets/` tree, e.g. `secrets/mihomo/secret.age` → `/run/agenix/mihomo/secret`. Override `name` when the logical key differs from the encrypted file, e.g. `github-pat` → `github/pat-work`. Override `path` only when a tool requires a fixed destination, e.g. WakaTime → `~/.wakatime.cfg`. Path collisions are caught at evaluation.

### `agenix -r` TTY gotcha

Re-keying after recipient changes in `secrets/keys.nix` **must** run from an interactive terminal:

```bash
cd secrets
agenix -r -i ~/.ssh/<private-key>
```

The agenix script checks `[ -t 0 ]` and overrides `EDITOR` to `cp -- /dev/stdin` when stdin lacks a TTY. That silently empties every secret before re-encrypting it. Never invoke from a script or Claude Code's Bash tool.

## Coding Conventions

### Module Shape

- **NixOS modules** in `modules/nixos/` are typically optionally enabled services. Define `options.hakula.services.<name>.enable`, gate with `config = lib.mkIf cfg.enable { ... }`, and enable from a host or profile.
- **Home Manager modules** in `home/modules/` live under `hakula.<name>`. Branch on `pkgs.stdenv.{isDarwin, isLinux}` for platform variants. The flags `isNixOS` / `isDesktop` are threaded by the host builders; only consume them when the host actually sets them.
- **Custom packages** in `packages/` are registered through the overlay (`lib/overlays.nix`) and consumed via `pkgs.<name>`.
- **Hosts** in `hosts/` register through one of the five `mk*` builders in `lib/builders.nix`. Reuse profiles from `hosts/_profiles/` for shared hardware / container shapes.

### Section Banners

Banners end at column 80, counting the indent. Use equals signs at the file header (no indent), dashes for inner subsections (indented to match surrounding code):

```nix
# ==============================================================================
# Module Name
# ==============================================================================

      # ------------------------------------------------------------------------
      # Subsection
      # ------------------------------------------------------------------------
```

Match nearby style. Avoid blanket-adding or blanket-removing. Option-bearing modules use `Module options` and `Module config` banners before the top-level `options` and `config` assignments. A flat module without banners stays flat.

### Comments

Defer to global CLAUDE.md. The repo-specific addition: when _restyling_ an existing file, match nearby comment style. Avoid blanket-deleting or blanket-adding. A file already wearing section banners gets a banner on the new section. A flat module without banners stays flat.

### Nix Style

- **Formatter**: `nixfmt` (enforced by pre-commit).
- **Linting**: `statix`, `deadnix` (CI). `statix.toml` suppresses W20 `repeated_keys` because the flat-key style is intentional.
- **Line width**: 100 chars (nixfmt default).
- **`with pkgs;`**: use in package lists for brevity.
- **`inherit` placement**: top of `let` blocks, like imports. Combine bindings from the same source: `inherit (pkgs.stdenv) isDarwin isLinux;`. Inside attribute sets, keep `inherit` in its logical position (e.g., `group` between `owner` and `path`).
- **Ordering**: group related fields first, then sort within the group when the names are self-describing. Avoid reshuffling semantic groups just for alphabetical order.

### Bash in Nix

- Multi-line layout for non-trivial flow (`if/else`, multi-arg `printf`, process substitutions). One-line invocations stay on one line.
- Quote variables. Use `set -euo pipefail` at the top of every script that runs more than one command.
- Use `lib.escapeShellArg` / `lib.escapeShellArgs` when interpolating Nix values into shell.
- Keep substantial scripts in adjacent `.sh` files and load them with `builtins.readFile`. Inline only short wrappers or generated snippets.

### Secrets Conventions

- Logical key first: `hakula.secrets.required."<service>/<secret>"`. Override `name` only when the encrypted source differs from the logical key. Override `path` only when a tool requires a fixed location.
- One canonical location per secret. Don't reference the same encrypted file under two logical keys.
- Mihomo-style secret substitution: use `awk` against `ENVIRON[]` so `|`, `&`, `\`, `'` survive into YAML. Validate the merged config before atomic swap.

### Git Conventions

- **Scope**: the module name (`mihomo`, `secrets`, `system-manager`), the file (`flake`, `claude`, `readme`), or `(host)` for host-scoped changes.
- Don't commit `data/corp-domain.nix` with the real value. The placeholder lives in git.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push / PR:

1. `nix flake check --all-systems` validates the flake structure and runs pre-commit hooks (`cspell`, `deadnix`, `markdownlint`, `nixfmt`, `statix`, `check-added-large-files`, `check-yaml`, `end-of-file-fixer`, `trim-trailing-whitespace`).
2. Parallel builds of every host (`us-1`..`us-4`, `sg-1`, `wsl`, `wsl-non-nixos`, `macbook`, `devvm-docker`).
3. Successful builds upload to the `hakula` Cachix cache on `main` or when the actor is `hakula139`.

## Proxy Configuration

`hakula.llm-assistants.proxy.*` fans out to each assistant (`claude-code`, `codex`, `opencode`). Proxy URL defaults to `http://127.0.0.1:7897` (local mihomo). Override via `url` or `secretUrlFile`. Enabled on `macbook`, `wsl-non-nixos`, and `devvm` (the last via `secretUrlFile`).

When network operations matter on these hosts, requests route through the proxy.

## Verification

Run before review:

```bash
nix flake check                                          # Flake structure + pre-commit hooks
git ls-files '*.nix' -z | xargs -0 nix fmt               # Format Nix files

# Per-host builds (cheaper than the full flake check):
nix build '.#nixosConfigurations.us-1.config.system.build.toplevel'
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#darwinConfigurations.macbook.system'
nix build '.#packages.x86_64-linux.devvm-docker'
```

When a refactor should be store-path-equivalent, e.g. a rename, extraction, or comment-only change, capture the output path of `nix build --no-link --print-out-paths '.#<target>'` before and after.

## Documentation Maintenance

- Keep `README.md` focused on user-facing value, supported features, and usage. Keep internal progress out.
- Match the project layout in this file to the filesystem. When directories move or land, update the tree.
- After substantive changes, sweep docs for stale claims: `README.md` Layout block, this file's project layout and conventions, host inventory tables, alias matrix.
