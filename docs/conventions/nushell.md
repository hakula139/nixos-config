# Nushell

Read this before writing or editing a `.nu` file. Nushell is the default for new helper scripts, since most of them parse an external tool's JSON and reshape it. Substantial scripts live in adjacent `.nu` files loaded with `builtins.readFile`, same as [bash](shell.md).

- **Entry point**: `def main` with typed parameters, so nushell checks arity and types for you.
- **Data**: records, since a delimited string has to be re-split at every use.
- **Output**: the `table` renderer.

## Traps

These either fail silently or raise an error that points somewhere other than the cause. For anything not listed here, the error message tells you.

- **`|| true` has no direct equivalent.** A failing external command aborts on its own, so a tolerated failure needs `try { ... }` or `| complete` plus an `.exit_code` read. `| complete` works on externals only, so a fallible builtin needs `try`.
- **`unset` has no equivalent either.** `hide-env --ignore-errors` drops a var from `$env`, and the removal does reach an external child, which is what lets a fetch bypass an inherited proxy.
- **`try` catches errors, `default` catches null, and `from json` does neither.** `open` on an empty file returns null without raising, and `from json` hands back non-JSON text unchanged, so a later cell path dies on a string with `incompatible_path_access`. Truncated JSON does raise, so plain text is the case that slips through. Check the shape (`$j | describe | str starts-with "record"`) before reading a field.
- **A `from yaml` failure hides its detail.** `$e.msg` is always `Error while parsing as yaml` and `$e.help` is null. The line naming the offending key sits in `$e.rendered`, and you only get it at all when the file extension is `.yaml`, since a string piped to `from yaml` reports `Unsupported input` instead.
- **A declared return type documents rather than coerces.** A `-> record` signature takes a `list<any>` silently whenever the mismatch is not statically visible, as when the value is bound to a variable first or comes back from an untyped helper. `get -o` on a list returns `[]`, so `| default 0` never fires and an `== 0` guard reads false: count with `where ... | length`.
- **A bare word is a string as an argument and a command call in a block.** `if $x { green }` runs `green`, so quote colour names. The silent half is the inverse: an untyped param receives `1min` as a `duration`, and a `: string` annotation coerces it back.
- **Never build a regex by interpolation.** `(` opens an interpolation in both `$"..."` and `$'...'`, so `(?<name>...)` parses as a command call and the error blames the regex text. `\(` escapes it in `$"..."` only, and even there `\d` is rejected as an unrecognized escape, so a `$"..."` cannot hold a regex either way. Concatenate: `($label + ' (?<n>\d+)')`. Nor can `$"(...)"` nest another `$"..."`.
- **A rest param claims your caller's flags.** `...args` makes `--porcelain` a flag on your own command, and a `list<string>` param only helps a def called from nushell, since every CLI arg arrives quoted. Quote the flag at the call site. The same limit means a script cannot accept an undeclared flag at all.
- **Argv safety ends at the shell boundary.** A list argument survives into `^command`, but `ssh` and `nix-shell --run` hand their argument to a remote shell, so quote by hand there.
- **Reading stdin needs `^cat`.** Top-level `$in` in a script file fails with `Can't evaluate block in IR mode` whatever the flags, and `$in` inside `def main` silently reads `nothing`. `writeNu`'s shebang omits `--stdin`, and the kernel passes a shebang tail as one argv element, so no second flag is reachable. The other obvious route, `open /dev/stdin`, re-opens fd 0 by path and raises ENXIO once the caller passes a socket rather than a pipe, which is what Node's `spawn` does. A shell test passes either way, since a shell pipeline really is a pipe.
- **`par-each --keep-order` is concurrent and ordered.** Never `print` inside the block, since threads interleave. Collect records and print after.

## In Nix

`pkgs.writers.writeNu` produces a plain script and `writeNuBin` produces `$out/bin/<name>`. Both take an optional attrset as their second argument, after the name. The `@placeholder@` plus `builtins.replaceStrings` pattern works unchanged and is how every site here supplies absolute store paths, and `builtins.toJSON` substitutes a list, since a nushell list literal accepts JSON verbatim.

Both writers prepend an absolute-store-path shebang, which demotes a script's own `#!/usr/bin/env nu` line to a comment. Keep that line anyway, since it makes the file runnable and LSP-checkable standalone. To spawn nushell from inside a generated script, read `$nu.current-exe` rather than substituting a store path.

## Linting

`nu-check` (`packages/nu-check/`) wraps `nu --ide-check`, which upstream `git-hooks-nix` does not offer. It gates delimiters and the arity of your own `def`s and little else, since a mistyped command name passes as an external call. None of the three bugs the nushell migration shipped were visible to it, so a script still needs one real run. `--ide-check` always exits 0 even for a missing path, hence the explicit `"severity":"Error"` filter and the missing-file and non-UTF-8 guards.

Indentation belongs to `editorconfig-checker`, which reads `.editorconfig` for every tracked file. `nufmt` stays out because it has no line-breaking logic, so it only joins: on current `health-check.nu` it collapsed a four-stage pipeline to 177 characters and another line to 221. It also reindents to four spaces, which contradicts the `[*.nu] indent_size = 2` the previous sentence relies on.

## What stays bash

Startup cost cuts both ways, so measure the script and ask what waits on the result. Nushell starts in ~33ms of CPU time against bash's ~3ms and a `jq` fork costs ~3ms, so on fork count alone a port pays only past a handful of forks. Fork count is the wrong test when nothing is waiting: `project-notify` forks twice and is nushell anyway, since the ~25ms it adds sits inside a ~235ms `toasty.exe` launch. The statusline is where the arithmetic does bind, because it renders synchronously and often. The three hook scripts under `shared/hooks/scripts/` read two fields each and stay bash, and they fail open, so a porting bug would disable a gate silently.

Three limits are structural rather than a matter of cost, so check them before proposing a port:

- **A `--run` or sourced script must be bash.** `profile-loader.sh` and `mkProxyScript` are injected through `makeWrapper --run`, so the wrapper's own shell evaluates them. `teammate-launcher.sh` inherits the constraint, since it sources `profile-loader.sh`.
- **An argv-forwarding wrapper cannot be expressed.** `nu script.nu --log-as-netdata` fails with `doesn't have flag`, and there is no argv escape hatch outside `def main` parameters, which rules out `systemd-cat-native`.
- **About half the rest are `exec` wrappers.** Setting a variable and handing off to the real binary has no data to structure. Nushell's `exec` does replace the process and does propagate `$env`, so these would work and gain nothing, while each rewrite risks the credential fallback. `notify` belongs here too, dispatching to `toasty.exe`, `notify-send` or `osascript` with no data of its own. `agent.sh` is the other holdout, reached through `writeShellApplication` rather than an inline body: it emits a `{key}value{/key}` wire format that is neither JSON nor tabular.

That accounts for every `writeShellScript*` site carrying a literal body, most of them a handful of lines. The rest take a Nix expression, several a `builtins.readFile` of an adjacent `.sh` file. Counting those lines by script is unreliable, since a nested or `''$`-escaped indented string defeats a naive scan, so the census is deliberately unnumbered.
