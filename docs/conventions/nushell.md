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
- **A `loop` body cannot carry one.** `loop` outputs `nothing`, so a `-> string` signature fails at parse time with `expected string, but command outputs nothing` blaming the loop, however every path out of it uses `return`. Either drop the annotation or express the search as a pipeline and take the first hit.
- **A bare word is a string as an argument and a command call in a block.** `if $x { green }` runs `green`, so quote colour names. The silent half is the inverse: an untyped param receives `1min` as a `duration`, and a `: string` annotation coerces it back.
- **Never build a regex by interpolation.** `(` opens an interpolation in both `$"..."` and `$'...'`, so `(?<name>...)` parses as a command call and the error blames the regex text. `\(` escapes it in `$"..."` only, and even there `\d` is rejected as an unrecognized escape, so a `$"..."` cannot hold a regex either way. Concatenate: `($label + ' (?<n>\d+)')`. Nor can `$"(...)"` nest another `$"..."`.
- **A comma separates list elements even inside a bare word.** `[--sort=-pcpu,-pmem]` is two arguments, so `ps` receives a stray `-pmem` and quietly returns a different set of rows. Quote any element holding a comma.
- **A rest param claims your caller's flags.** `...args` makes `--porcelain` a flag on your own command, and a `list<string>` param only helps a def called from nushell, since every CLI arg arrives quoted. Quote the flag at the call site. The same limit means a script cannot accept an undeclared flag at all.
- **Argv safety ends at the shell boundary.** A list argument survives into `^command`, but `ssh` and `nix-shell --run` hand their argument to a remote shell, so quote by hand there.
- **Reading stdin needs `^cat`.** Top-level `$in` in a script file fails with `Can't evaluate block in IR mode` whatever the flags, and `$in` inside `def main` silently reads `nothing`. `writeNu`'s shebang omits `--stdin`, and the kernel passes a shebang tail as one argv element, so no second flag is reachable. The other obvious route, `open /dev/stdin`, re-opens fd 0 by path and raises ENXIO once the caller passes a socket rather than a pipe, which is what Node's `spawn` does. A shell test passes either way, since a shell pipeline really is a pipe.
- **`par-each --keep-order` is concurrent and ordered.** Never `print` inside the block, since threads interleave. Collect records and print after.

## In Nix

`pkgs.writers.writeNu` produces a plain script and `writeNuBin` produces `$out/bin/<name>`. Both take an optional attrset as their second argument, after the name. The `@placeholder@` plus `builtins.replaceStrings` pattern works unchanged and is how every site here supplies absolute store paths, and `builtins.toJSON` substitutes a list, since a nushell list literal accepts JSON verbatim.

Both writers prepend an absolute-store-path shebang, which demotes a script's own `#!/usr/bin/env nu` line to a comment. Keep that line anyway, since it makes the file runnable and LSP-checkable standalone. To spawn nushell from inside a generated script, read `$nu.current-exe` rather than substituting a store path.

Neither writer validates a `use` target. A missing or misspelled substitution builds clean, then dies at parse time before any `try` can fail open, so a script that has to fail open is better off duplicating a helper than importing one.

## Linting

`nu-check` (`packages/nu-check/`) wraps `nu --ide-check`. It gates delimiters and the arity of your own `def`s and little else, since a mistyped command name passes as an external call, so a script still needs one real run.

Indentation belongs to `editorconfig-checker`, which reads `.editorconfig` for every tracked file. `nufmt` is unused: it only joins lines, and it reindents to four spaces against the `[*.nu] indent_size = 2` in force here.

## What stays bash

Nushell is the default, so what follows is the exception list, and every entry earns its place structurally. Interpreter startup costs tens of milliseconds, which the hook budget here already absorbs, so it never qualifies on its own.

- **A `--run` or sourced script.** `profile-loader.sh` and `mkProxyScript` are injected through `makeWrapper --run`, so the wrapper's own shell evaluates them. `teammate-launcher.sh` sources `profile-loader.sh`.
- **An argv-forwarding wrapper.** `nu script.nu --log-as-netdata` fails with `doesn't have flag`, and there is no argv escape hatch outside `def main` parameters, which rules out `systemd-cat-native`.
- **`exec` wrappers.** Setting a variable and handing off to the real binary has no data to structure. This covers the MCP wrappers, `notify`, and most of the remaining `writeShellScript` sites.

Every hook fails open, so a porting bug reads as a gate that quietly stopped firing. Diff the old script against the new over a battery of hook payloads before deleting the bash.
