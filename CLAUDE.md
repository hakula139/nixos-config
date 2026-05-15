# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository. Anything inferable from `flake.nix`, the directory tree, or a representative module belongs in the code, not here.

## Repository Overview

A flake-based NixOS / nix-darwin / system-manager configuration:

- **5 NixOS servers** (us-1, us-2, us-3, us-4, sg-1) on x86_64-linux
- **1 macOS workstation** (hakula-macbook) on aarch64-darwin
- **1 generic Linux** (hakula-linux) on system-manager + Home Manager
- **1 Docker image** (hakula-devvm) for air-gapped deployment

`flake.nix` is the manifest. Builders live in `lib/builders.nix`, overlays in `lib/overlays.nix`. Per-host config in `hosts/`. Cross-platform primitives in `modules/shared.nix`.

## Bootstrap Commands

First-time setup is the workflow that's hard to infer from the codebase. Day-to-day applies use the `nixsw` zsh alias on every platform.

```bash
# NixOS server
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>

# macOS
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake '.#hakula-macbook'

# Generic Linux
nix run '.#system-manager' -- switch --flake '.#hakula-linux' --sudo
system-manager-health-check agenix-install-secrets.service home-manager-hakula.service
```

Multi-server deploys go through Colmena: `colmena apply --on us-4`, or `--on @cloudcone` for provider tags.

## Secrets

Two helpers in `lib/secrets.nix`, two contracts:

- **System-side** (NixOS / Darwin / system-manager modules):
  ```nix
  age.secrets.<attr> = secrets.mkSecret { name = "<service>/<secret>"; owner = "..."; group = "..."; };
  ```
- **User-side** (Home Manager modules):
  ```nix
  hakula.secrets.required."<service>/<secret>" = { };
  ```
  then resolve via the `secretPath` module argument: `secretPath "<service>/<secret>"`.

Decrypted runtime paths mirror the `secrets/` tree (e.g. `secrets/mihomo/secret.age` → `/run/agenix/mihomo/secret`). Override `name` when the logical key differs from the encrypted file (e.g. `github-pat` → `github/pat-work`). Override `path` only when a tool requires a fixed destination (e.g. `wakatime/config` → `~/.wakatime.cfg`).

### `agenix -r` TTY gotcha

Re-keying after changing recipients in `secrets/keys.nix` **must** run from an interactive terminal:

```bash
cd secrets
agenix -r -i ~/.ssh/<private-key>
```

The agenix script checks `[ -t 0 ]` and overrides `EDITOR` to `cp -- /dev/stdin` when stdin is not a TTY, which silently empties every secret before re-encrypting. Never run from a script or Claude Code's Bash tool.

## Code Style

- **Formatter**: `nixfmt` (enforced by pre-commit).
- **Linting**: `statix`, `deadnix` (enforced in CI). `statix.toml` suppresses W20 `repeated_keys`; the flat-key style is intentional.
- **Line width**: 100 chars.
- **Comments**: WHY only, never WHAT. Defer to `~/.claude/CLAUDE.md` for the comment doctrine.
- **`inherit` placement**: top of `let` blocks, like imports. Combine bindings from the same source: `inherit (pkgs.stdenv) isDarwin isLinux;`.

## Proxy Configuration

`hakula.llm-assistants.proxy.*` fans out to each assistant (`claude-code`, `codex`, `opencode`). The proxy URL defaults to `http://127.0.0.1:7897` (local mihomo); override via `url` or `secretUrlFile`. Currently enabled on `hakula-macbook`, `hakula-linux`, and `hakula-devvm` (the last via `secretUrlFile`).

When network operations matter on these hosts, remember requests route through the proxy.
