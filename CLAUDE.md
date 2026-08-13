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
│   ├── corp-hosts.nix               # Corp-internal hostnames and URLs
│   ├── servers.nix                  # Server inventory (IP, port, provider, host keys, builder config)
│   └── system-manager.nix           # Runtime PATH entries provisioned by system-manager activation
├── lib/                             # Pure helpers and framework code
│   ├── builders.nix                 # mkDarwin, mkDocker, mkHomeManagerConfig, mkServer, mkSystemManager, mkWSL, serverSharedModules
│   ├── editorconfig.nix             # Reads `.editorconfig` settings for tools that cannot
│   ├── nu-check.nu                  # Pre-commit gate: `nu --ide-check` diagnostics plus indentation
│   ├── overlays.nix                 # nixpkgs overlay (channels, flake-input CLIs, upstream overrides, toolchains, custom packages)
│   ├── proxy.nix                    # mkProxyOptions, mkProxyScript, wrapWithProxy, no_proxy rendering
│   ├── secrets.nix                  # mkSecret, mkRequiredUserSecrets, secretFile, secretPath
│   ├── systemd.nix                  # Shared systemd unit hardening defaults
│   ├── tooling.nix                  # Shared tool groups (nix, secrets, shell)
│   ├── llm-assistants/              # Shared LLM-assistant helpers (mcpOptions, proxy, claude profile sets)
│   └── wsl/                         # Windows interop helpers (windows-interop.nu)
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
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake '.#macbook'
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

- **Formatter**: `shfmt` (enforced by pre-commit). Layout comes from `.editorconfig`, though the flags are restated in `flake.nix`, since the `git-hooks-nix` hook always passes `-ln` and any flag makes `shfmt` ignore the file. `simplify` is off because it strips the quotes inside `[[ ]]` that the rule below requires.
- Multi-line layout for non-trivial flow (`if/else`, multi-arg `printf`, process substitutions). One-line invocations stay on one line.
- Quote variables. Use `set -euo pipefail` at the top of every script that runs more than one command.
- Use `lib.escapeShellArg` / `lib.escapeShellArgs` when interpolating Nix values into shell.
- Keep substantial scripts in adjacent `.sh` files and load them with `builtins.readFile`. Inline only short wrappers or generated snippets.

### Nushell

Nushell is the default for new helper scripts, since most of them parse JSON from an external tool and reshape it. Bash remains correct for the cases listed under "What stays bash" below.

- **No `set -euo pipefail` equivalent, and none needed.** A failing external command aborts the script on its own, and an undefined variable is a parse-time error. The habit that does not carry over is `|| true`: where bash tolerated a failure, wrap the call in `try { ... }` or capture it with `| complete` and read `.exit_code`. Omitting that turns a tolerated failure into an abort.
- **`| complete` works on externals only.** On a builtin like `cp` it errors outright, so a fallible builtin needs `try { ... } catch { ... }`.
- **`try` guards errors, `default` guards null.** They are separate failure modes. `open` on an empty `.json` returns null rather than raising, so `try { open $f } catch { {} }` passes the null straight through to whatever unwraps it next. Write `try { open $f | default {} } catch { {} }`.
- **A declared return type is documentation, not a coercion.** `transpose -r -d` and `uniq --count | transpose` yield `list<any>` on empty input, and a `-> record` signature accepts it silently. The next `in` or field access then raises. Guard the empty case before transposing. Worse, `get -o` on a list returns `[]` rather than null, so `| default 0` never fires and an `== 0` guard reads false: count with `where ... | length` instead.
- **`def main` is the entry point.** Declare parameters with types and defaults (`def main [cmd: string = "check"]`) instead of `"${1:-check}"` plus a `case` fallthrough. Nushell generates the usage message and rejects a missing argument for you.
- **Reading stdin needs `open --raw /dev/stdin`.** `$in` at the top level of a script fails with `Can't evaluate block in IR mode`, because `writeNu` invokes `nu --no-config-file` without `--stdin`. `$in` only binds to stdin inside `def main` when `--stdin` is passed, which the writer does not do.
- **Prefer structured data end to end.** `from json`, `get field?` (the `?` yields null instead of erroring), `where`, and `select` replace a chain of `jq -r` subprocesses. Return a list of records and let the built-in `table` renderer format it rather than hand-building widths with `printf '%-28s'`. Return a record instead of packing several values into a delimited string for the caller to re-split.
- **Call externals with a `^` prefix** when the name could collide with a builtin, and quote nothing extra: nushell passes arguments as a list, so word splitting cannot happen.
- **Pass external flags as a `list<string>`, never a rest param.** A `...args` parameter claims `--flag` as a flag on your own command, so `git-porcelain $cwd status --porcelain` fails with "doesn't have flag `porcelain`".
- **Use `ansi <name>` over literal escapes.** `ansi white_dimmed` and `ansi blue_bold` emit exactly what `\033[2;37m` and `\033[1;34m` did. Note `ansi green` is `ESC[32m` where a hand-written constant was often `ESC[0;32m`; the two render identically.
- **A bare word is a string in argument position and a command call in block position.** `labeled Ctx "0%" green` passes strings, but `if $x { green }` tries to run `green`. Quote colour names and anything else that could parse as a duration or command (`"1m"` is a 1-minute duration unquoted).
- **`$"(...)"` cannot nest another `$"..."`.** The lexer ends the string at the inner quote. Build the value with concatenation and single quotes instead: `$"(dim ($label + ':'))"`.
- **Never build a regex with `$"..."` or `$'...'`.** A `(` opens an interpolation in both forms and `\(` does not escape it, so `(?<name>...)` is parsed as a command call. Concatenate instead: `($label + ' (?<n>\d+)')`.
- **Ranges are inclusive.** `0..2` is three elements; use `0..<2` for the bash `${s:0:2}` equivalent.
- **`math sum` errors on an empty list.** Append the identity first: `| append 0 | math sum`.
- **Operators cannot lead or trail a continuation line.** Wrap a multi-line boolean in parens, otherwise a leading `and` parses as a command.
- **`parse --regex` collapses the empty-input case.** Piping no-match or empty text through `parse | get -o 0 | default {...}` replaces a length guard plus a branch.
- Same file conventions as bash: substantial scripts live in adjacent `.nu` files loaded with `builtins.readFile`, and section banners follow the rules above.

#### Nushell in Nix

`pkgs.writers.writeNu` and `writeNuBin` are upstream, so this repo defines no writer of its own. `writeNu` produces a plain script (for a `home.file` source or a hook target) and `writeNuBin` produces `$out/bin/<name>` (for `home.packages`). Both accept an optional attrset first, so `makeWrapperArgs` supplies runtime `PATH` entries the way `writeShellApplication`'s `runtimeInputs` does.

The `@placeholder@` plus `builtins.replaceStrings` substitution pattern works unchanged, since it operates on the file text before the writer sees it. Substitute a list with `builtins.toJSON`, which a nushell list literal accepts verbatim, in place of `lib.escapeShellArgs`.

#### Linting and formatting

The `nu-check` pre-commit hook wraps `nu --ide-check` (`lib/nu-check.nu`). It catches unbalanced delimiters, undefined variables, wrong arity and flags on your own `def`s, and type mismatches against declared signatures. It does not catch an unknown external command, nor a bad field on a built-in record such as `$nu.home-path` (the real name is `$nu.home-dir`), so a script still needs one real run.

`--ide-check` always exits 0, including for a path that does not exist, which is why the hook both filters for `"severity":"Error"` and rejects a missing file. The same hook rejects a tab indent or an indent that is not a multiple of the `[*.nu]` `indent_size`, which is the part of formatting that can be checked without rewriting the file.

`.editorconfig` is the one source for indentation. `lib/editorconfig.nix` reads it, since `builtins.fromTOML` rejects the format (`[*.nu]` is not a valid TOML key), and both `nu-check` and `shfmt` take their layout from there. An absent setting throws at evaluation rather than falling back to a tool default that would contradict the file.

`nufmt` stays out of the pipeline. Its `indent: 2` config option does fix the width, but `line_length` is advisory and ignored (a 40-column limit still emitted 122 characters), it has no line-breaking logic at all so it only ever joins lines, and `margin` governs blank lines between top-level items while every blank line inside a block is stripped. Running it over `modules/system-manager/health-check.nu` collapsed a four-stage pipeline into one 163-character line. Re-measure before reconsidering, since it is pre-1.0 and its README already documents options this build rejects.

#### What stays bash

- `modules/nixos/cloudcone/agent/agent.sh` runs as a systemd service on a minimal VPS. It predates the runtime being available fleet-wide and there is no reason to grow that closure further for one script.
- `claude-code/scripts/profile-loader.sh` is injected into a `makeWrapper --run` context, so its text is evaluated by the wrapper's own bash. `teammate-launcher.sh` sources it. Nushell cannot mutate a parent bash environment, so both are structurally bash.
- The four hook scripts under `shared/hooks/scripts/` stay bash for now. They are invoked by an external tool that expects specific exit codes and stdout shapes, and two of them fail open, so a porting bug would silently disable a gate rather than failing loudly.

Startup cost is not a reason to stay on bash. Nushell's interpreter starts slower than bash, but a script that forks `jq` a few times loses more to subprocesses than it gains: the statusline renders faster in nushell (112ms vs 133ms) because it parses its JSON once in-process instead of shelling out five times.

### Secrets Conventions

- Logical key first: `hakula.secrets.required."<service>/<secret>"`. Override `name` only when the encrypted source differs from the logical key. Override `path` only when a tool requires a fixed location.
- One canonical location per secret. Don't reference the same encrypted file under two logical keys.
- Mihomo-style secret substitution: use `awk` against `ENVIRON[]` so `|`, `&`, `\`, `'` survive into YAML. Validate the merged config before atomic swap.

### Git Conventions

- **Scope**: the module name (`mihomo`, `secrets`, `system-manager`), the file (`flake`, `claude`, `readme`), or `(host)` for host-scoped changes.
- Don't commit `data/corp-domain.nix` with the real value. The placeholder lives in git.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push / PR:

1. `nix flake check --all-systems` validates the flake structure and runs pre-commit hooks (`cspell`, `deadnix`, `markdownlint`, `nixfmt`, `nu-check`, `shfmt`, `statix`, `check-added-large-files`, `check-yaml`, `end-of-file-fixer`, `trim-trailing-whitespace`).
2. Parallel builds of every host (`us-1..us-4`, `sg-1`, `wsl`, `wsl-non-nixos`, `macbook`, `devvm-docker`).
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
