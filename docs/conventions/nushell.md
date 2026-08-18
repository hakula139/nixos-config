# Nushell

Read this before writing or editing a `.nu` file. Nushell is the default for new helper scripts, since most of them parse an external tool's JSON and reshape it. Substantial scripts live in adjacent `.nu` files loaded with `builtins.readFile`, same as [bash](shell.md).

Prefer `def main` with typed parameters over positional `$1` parsing, records over delimited strings, and the `table` renderer over hand-built `printf` widths.

## Traps

These fail silently or read as something else. For anything not listed here, the error message tells you.

- **`|| true` has no direct equivalent.** A failing external command aborts on its own, so a tolerated failure needs `try { ... }` or `| complete` plus an `.exit_code` read. `| complete` works on externals only, so a fallible builtin needs `try`.
- **`try` catches errors, `default` catches null, and `from json` does neither.** `open` on an empty file returns null without raising, and `from json` hands back non-JSON text unchanged, so a later field access fails with `Input type not supported` blaming the field access while the real fault is upstream. Check the shape (`$j | describe | str starts-with "record"`) before reading a field.
- **A declared return type documents rather than coerces.** `transpose` yields `list<any>` on empty input and a `-> record` signature takes it silently. `get -o` on a list returns `[]`, so `| default 0` never fires and an `== 0` guard reads false: count with `where ... | length`.
- **Never build a regex by interpolation.** `(` opens an interpolation in both `$"..."` and `$'...'`, and `\(` does not escape it, so `(?<name>...)` parses as a command call. Concatenate: `($label + ' (?<n>\d+)')`. Nor can `$"(...)"` nest another `$"..."`.
- **A rest param claims your caller's flags.** `...args` makes `--porcelain` a flag on your own command. Pass `list<string>` instead. The same limit means a script cannot accept an undeclared flag at all.
- **Reading stdin needs `^cat`.** `writeNu` omits `--stdin`, so `$in` at top level fails with `Can't evaluate block in IR mode`. The other obvious route, `open /dev/stdin`, re-opens fd 0 by path and raises ENXIO once the caller passes a socket rather than a pipe, which is what Node's `spawn` does. A shell test passes either way, since a shell pipeline really is a pipe.
- **A bare word is a string as an argument and a command call in a block.** `if $x { green }` runs `green`. Quote colour names, and anything parseable as a duration (`1m`).
- **`par-each --keep-order` is concurrent and ordered.** Never `print` inside the block, since threads interleave. Collect records and print after.
- **Argv safety ends at the shell boundary.** A list argument survives into `^command`, but `ssh` and `nix-shell --run` hand their argument to a remote shell, so quote by hand there.

## In Nix

`pkgs.writers.writeNu` produces a plain script and `writeNuBin` produces `$out/bin/<name>`. Both take an optional attrset first, so `makeWrapperArgs` supplies runtime `PATH`. The `@placeholder@` plus `builtins.replaceStrings` pattern works unchanged, and `builtins.toJSON` substitutes a list, since a nushell list literal accepts JSON verbatim.

Both writers prepend an absolute-store-path shebang, which demotes a script's own `#!/usr/bin/env nu` line to a comment. Keep that line anyway, since it makes the file runnable and LSP-checkable standalone. To spawn nushell from inside a generated script, read `$nu.current-exe` rather than substituting a store path.

## Linting

`nu-check` (`packages/nu-check/`) wraps `nu --ide-check`, which upstream `git-hooks-nix` does not offer. It gates delimiters and the arity of your own `def`s and little else, since a mistyped command name passes as an external call. None of the three bugs the nushell migration shipped were visible to it, so a script still needs one real run. `--ide-check` always exits 0 even for a missing path, hence the explicit `"severity":"Error"` filter and the missing-file and non-UTF-8 guards.

Indentation belongs to `editorconfig-checker`, which reads `.editorconfig` for every tracked file. `nufmt` stays out: `line_length` is advisory, there is no line-breaking logic so it only joins, and it collapsed a four-stage pipeline in `health-check.nu` into one 163-character line.

## What stays bash

Startup cost cuts both ways, so measure the script. Nushell starts in ~33ms against bash's ~2ms and a `jq` fork costs ~2ms, so parsing in-process wins only past a handful of forks. The statusline crossed that line at five forks (112ms against 133ms), where the three hook scripts under `shared/hooks/scripts/` read three fields and do not (8.6ms against 24.7ms), and they fail open, so a porting bug would disable a gate silently.

Three limits are structural rather than a matter of cost, so check them before proposing a port:

- **A `--run` or sourced script must be bash.** `profile-loader.sh` and `mkProxyScript` are injected through `makeWrapper --run`, so the wrapper's own shell evaluates them. `teammate-launcher.sh` inherits the constraint, since it sources `profile-loader.sh`.
- **An argv-forwarding wrapper cannot be expressed.** `nu script.nu --log-as-netdata` fails with `doesn't have flag`, and there is no argv escape hatch outside `def main` parameters, which rules out `systemd-cat-native`.
- **Most of the rest are `exec` wrappers.** Setting a variable and handing off to the real binary has no data to structure. Nushell's `exec` does replace the process and does propagate `$env`, so these would work and gain nothing, while each rewrite risks the credential fallback. `agent.sh` is the other holdout: it emits a `{key}value{/key}` wire format that is neither JSON nor tabular.

That accounts for the ~150 non-blank lines of inline shell across the 24 `writeShellScript*` sites that carry an inline body, 60 of which sit in `mihomo`'s two scripts. The other six calls load a `.sh` file.

`mihomo-update` is the one substantial rejection, and worth knowing before proposing it again. Nushell handles most of it better, since `str replace --all` is literal and retires the `awk`/`ENVIRON[]` quote-escaping. It fails on validation: the script merges base config and subscription as text, so a provider shipping its own `mode:` or `dns:` yields a duplicate key that `yq -e .` accepts and mihomo resolves last-wins, where `from yaml` rejects it outright with no flag to relax. Verified against `yq-go` 4.53.2 on a merged fixture.

Two smaller ones are worth naming. `get-tty-num` runs on every statusline render and forks `ps` in a loop either way, so nushell would only add its startup to a measured hot path. `project-notify` does fork `jq` three times, but only for Codex's payload argument, once per response.
