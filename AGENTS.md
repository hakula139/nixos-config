# AGENTS.md: nixos-config

Project-specific rules for any coding assistant working in this repository. `CLAUDE.md` is a symlink to this file. Follow the user's global instructions for communication, scope, comment, and commit doctrine.

Keep this file short. Anything a model can read off `flake.nix`, a representative module, or `git log` belongs in the code rather than here. What earns a place is a constraint that is invisible, destructive, or already cost someone a debugging session.

## Repository Overview

A flake-based NixOS / nix-darwin / system-manager configuration covering 5 servers, 3 workstations (NixOS-WSL, system-manager on non-NixOS WSL, Darwin), and a Docker image for air-gapped deployment. `flake.nix` registers every host through one of the five `mk*` builders in `lib/builders.nix`.

`hosts/_profiles/` splits into `platform/` for hardware or runtime shape and `role/` for server against workstation. `data/` holds static inventory, where `corp-domain.nix` keeps a placeholder in git while the real value stays working-tree only.

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
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake '.#macbook'
```

Multi-server deploys go through Colmena: `colmena apply --on us-4`, `colmena apply --on @cloudcone` for provider tags.

## Secrets

`lib/secrets.nix` has two contracts: system modules declare `age.secrets.<attr> = secrets.mkSecret { name = "<service>/<secret>"; ... }`, and Home Manager modules declare `hakula.secrets.required."<service>/<secret>"` then resolve through the `secretPath` argument.

Decrypted paths mirror the `secrets/` tree, so `secrets/mihomo/secret.age` becomes `/run/agenix/mihomo/secret`. Override `name` when the logical key differs from the encrypted file, and `path` only when a tool demands a fixed location (WakaTime wants `~/.wakatime.cfg`). One canonical location per secret, so never reference the same encrypted file under two logical keys, and collisions are caught at evaluation.

### `agenix -r` TTY gotcha

Re-keying after a recipient change in `secrets/keys.nix` **must** run from an interactive terminal (`cd secrets && agenix -r -i ~/.ssh/<key>`). The script checks `[ -t 0 ]` and overrides `EDITOR` to `cp -- /dev/stdin` when stdin lacks a TTY, which silently empties every secret before re-encrypting it. Never invoke it from a script or an assistant's shell tool.

## Coding Conventions

### Module Shape

- **NixOS modules** in `modules/nixos/` are typically optionally enabled services. Define `options.hakula.services.<name>.enable`, gate with `config = lib.mkIf cfg.enable { ... }`, and enable from a host or profile.
- **Home Manager modules** in `home/modules/` live under `hakula.<name>`. Branch on `pkgs.stdenv.{isDarwin, isLinux}` for platform variants. The flags `isNixOS` / `isDesktop` are threaded by the host builders, so only consume them when the host actually sets them.
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

Option-bearing modules use `Module options` and `Module config` banners before the top-level `options` and `config` assignments. When restyling an existing file, match nearby style rather than blanket-adding or blanket-removing: a file already wearing banners gets one on the new section, and a flat module stays flat. The same applies to comment density.

### Nix Style

- **Formatter**: `nixfmt` (enforced by pre-commit).
- **Linting**: `statix`, `deadnix` (CI). `statix.toml` suppresses W20 `repeated_keys` because the flat-key style is intentional.
- **Line width**: 100 chars (nixfmt default).
- **`with pkgs;`**: use in package lists for brevity.
- **`inherit` placement**: top of `let` blocks, like imports. Combine bindings from the same source: `inherit (pkgs.stdenv) isDarwin isLinux;`. Inside attribute sets, keep `inherit` in its logical position (e.g., `group` between `owner` and `path`).
- **Ordering**: group related fields first, then sort within the group when the names are self-describing. Avoid reshuffling semantic groups just for alphabetical order.

### Bash in Nix

- **Formatter**: `shfmt` (enforced by pre-commit), reading its layout straight from `.editorconfig`. Every `settings` value in `flake.nix` is left unset on purpose, since the `git-hooks-nix` hook only omits a formatting flag when the setting is null or false, and any flag switches `shfmt` out of EditorConfig mode into its own defaults, which are tabs. It honors its own extension keys there too, `binary_next_line` and `switch_case_indent`. `simplify` stays off because it strips the quotes inside `[[ ]]` that the rule below requires.
- Multi-line layout for non-trivial flow (`if/else`, multi-arg `printf`, process substitutions). One-line invocations stay on one line.
- Quote variables. Use `set -euo pipefail` at the top of every script that runs more than one command.
- Use `lib.escapeShellArg` / `lib.escapeShellArgs` when interpolating Nix values into shell.
- Keep substantial scripts in adjacent `.sh` files and load them with `builtins.readFile`. Inline only short wrappers or generated snippets.

### Nushell

The default for new helper scripts, since most of them parse an external tool's JSON and reshape it. Substantial scripts live in adjacent `.nu` files loaded with `builtins.readFile`, same as bash.

Traps that fail silently or read as something else. Everything not listed here, the error message tells you.

- **`|| true` has no direct equivalent.** A failing external command aborts on its own, so a tolerated failure needs `try { ... }` or `| complete` plus an `.exit_code` read. `| complete` works on externals only, so a fallible builtin needs `try`.
- **`try` catches errors, `default` catches null, and `from json` does neither.** `open` on an empty file returns null without raising, and `from json` hands back non-JSON text unchanged, so a later field access dies on a string with `incompatible_path_access`. Check the shape (`$j | describe | str starts-with "record"`) before reading a field.
- **A declared return type documents rather than coerces.** `transpose` yields `list<any>` on empty input and a `-> record` signature takes it silently. `get -o` on a list returns `[]`, so `| default 0` never fires and an `== 0` guard reads false: count with `where ... | length`.
- **Never build a regex by interpolation.** `(` opens an interpolation in both `$"..."` and `$'...'`, and `\(` does not escape it, so `(?<name>...)` parses as a command call. Concatenate: `($label + ' (?<n>\d+)')`. Nor can `$"(...)"` nest another `$"..."`.
- **A rest param claims your caller's flags.** `...args` makes `--porcelain` a flag on your own command. Pass `list<string>` instead. The same limit means a script cannot accept an undeclared flag at all.
- **Reading stdin needs `^cat`.** `writeNu` omits `--stdin`, so `$in` at top level fails with `Can't evaluate block in IR mode`. The other obvious route, `open /dev/stdin`, re-opens fd 0 by path and raises ENXIO once the caller passes a socket rather than a pipe, which is what Node's `spawn` does. A shell test passes either way, since a shell pipeline really is a pipe.
- **A bare word is a string as an argument and a command call in a block.** `if $x { green }` runs `green`. Quote colour names, and anything parseable as a duration (`1m`).
- **`par-each --keep-order` is concurrent and ordered.** Never `print` inside the block, since threads interleave. Collect records and print after.

Prefer `def main` with typed parameters over positional `$1` parsing, records over delimited strings, and the `table` renderer over hand-built `printf` widths.

#### Nushell in Nix

`pkgs.writers.writeNu` produces a plain script and `writeNuBin` produces `$out/bin/<name>`. Both take an optional attrset first, so `makeWrapperArgs` supplies runtime `PATH`. The `@placeholder@` plus `builtins.replaceStrings` pattern works unchanged, and `builtins.toJSON` substitutes a list, since a nushell list literal accepts JSON verbatim.

#### Linting and formatting

`nu-check` (`packages/nu-check/`) wraps `nu --ide-check`, which upstream `git-hooks-nix` does not offer. It gates delimiters and the arity of your own `def`s and little else, since a mistyped command name passes as an external call. None of the three bugs the nushell migration shipped were visible to it, so a script still needs one real run. `--ide-check` always exits 0 even for a missing path, hence the explicit `"severity":"Error"` filter and the missing-file and non-UTF-8 guards.

Indentation belongs to `editorconfig-checker`, which reads `.editorconfig` for every tracked file. `nufmt` stays out: `line_length` is advisory, there is no line-breaking logic so it only joins, and it collapsed a four-stage pipeline in `health-check.nu` into one 163-character line.

#### What stays bash

Startup cost cuts both ways, so measure the script rather than assuming. Nushell starts in ~33ms against bash's ~2ms and a `jq` fork costs ~2ms, so parsing in-process wins only past a handful of forks. The statusline crossed that line at five forks (112ms against 133ms), where the three hook scripts under `shared/hooks/scripts/` read three fields and do not (8.6ms against 24.7ms), and they fail open, so a porting bug would disable a gate silently.

Two limits are structural rather than a matter of cost. A script injected by `makeWrapper --run` or sourced is evaluated by the wrapper's own bash, which covers `profile-loader.sh`, `teammate-launcher.sh`, `mkProxyScript`, and `claude-mcp-config-guard`. An argv-forwarding wrapper like `systemd-cat-native` cannot be expressed, because of the undeclared-flag limit above. Beyond those, the ~225 lines of inline shell across 33 `writeShellScript*` sites are `exec` wrappers with no data to structure, and `agent.sh` emits a `{key}value{/key}` wire format that is neither JSON nor tabular.

`mihomo-update` is the one substantial rejection, and worth knowing before proposing it again. Nushell handles most of it better, since `str replace --all` is literal and retires the `awk`/`ENVIRON[]` quote-escaping. It fails on validation: the script merges base config and subscription as text, so a provider shipping its own `mode:` or `dns:` yields a duplicate key that `yq -e .` accepts and mihomo resolves last-wins, where `from yaml` rejects it outright with no flag to relax.

### Git Conventions

- **Scope**: the module name (`mihomo`, `secrets`, `system-manager`), the file (`flake`, `claude`, `readme`), or `(host)` for host-scoped changes.
- Don't commit `data/corp-domain.nix` with the real value. The placeholder lives in git.

## CI

`.github/workflows/ci.yml` runs `nix flake check --all-systems` plus a parallel build of all 10 targets on every push and PR. `macbook` cannot be built on Linux (the Brewfile derivation fails a platform check), so CI is the only verification for Darwin changes.

## Proxy Configuration

`hakula.llm-assistants.proxy.*` fans out to each assistant (`claude-code`, `codex`, `opencode`). Proxy URL defaults to `http://127.0.0.1:7897` (local mihomo). Override via `url` or `secretUrlFile`. Enabled on `macbook`, `wsl-non-nixos`, and `devvm` (the last via `secretUrlFile`).

When network operations matter on these hosts, requests route through the proxy.

## Verification

`nix flake check` covers structure and the pre-commit hooks. A per-host build is cheaper when iterating:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#packages.x86_64-linux.devvm-docker'
```

When a change should be store-path-equivalent, e.g. a rename or a comment-only edit, compare `nix build --no-link --print-out-paths` before and after. Note that `checks.pre-commit` does not force host modules, so a broken reference there only shows up in a host build.

## Documentation Maintenance

- Keep `README.md` focused on user-facing value, supported features, and usage. Keep internal progress out.
- Match the project layout in this file to the filesystem. When directories move or land, update the tree.
- After substantive changes, sweep docs for stale claims: `README.md` Layout block, this file's project layout and conventions, host inventory tables, alias matrix.
