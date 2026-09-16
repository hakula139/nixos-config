# Nushell

Read this before writing or editing a `.nu` file. Nushell is the default for new helper scripts, since most of them parse an external tool's JSON and reshape it. Substantial scripts live in adjacent `.nu` files loaded with `builtins.readFile`, same as [bash](shell.md).

- **Script-relative resources**: bind `const SCRIPT_DIR = path self .` after the file header and imports, before application configuration. It resolves from the defining file at parse time, so sibling resources do not depend on the caller's working directory or runtime environment. When Nix copies the script into the store, those resources must be packaged alongside it.
- **Entry point**: `def main` with typed parameters, so nushell checks arity and types for you.
- **Help**: keep script headers to their purpose, operating constraints, and a `--help` pointer. Document commands and parameters at their definitions so generated help contains the usage details.
- **Data**: records, since a delimited string has to be re-split at every use.
- **Output**: the `table` renderer.
- **Regexes**: precede each non-obvious regex with a short label for the construct it matches. Restating the decoded pattern improves readability here.

## Traps

### Parsing and data

- **`try` catches errors, `default` catches null.** `open` on an empty file returns null, and `from json` accepts some plain text as a string. Truncated JSON raises an error. Check the parsed shape (`$j | describe | str starts-with "record"`) before reading a field, since parsing alone does not establish that it is a record.
- **YAML error summaries omit parser details.** Use `$e.rendered` in a catch block to retain the nested parse error. This works for both `open file.yaml` and strings piped to `from yaml`, while `$e.msg` alone can report only `Error while parsing as yaml`.
- **Return annotations do not validate dynamically typed output.** A `-> record` function can still return a list from an untyped helper. `get -o` on a list returns `[]`, which `default` leaves unchanged. Count matching rows with `where ... | length` when the caller needs a count.
- **`loop` is typed as `nothing`.** A function declared `-> string` cannot end in `loop`, even when every exit path returns a string. Drop the annotation or express the search as a pipeline.

### Strings and arguments

- **Bare words depend on context.** `if $x { green }` calls a command named `green`, so quote literal colour names in blocks. An untyped argument such as `1min` arrives as a duration, while a `: string` parameter coerces it to a string.
- **Build dynamic regexes by concatenation.** Parentheses start interpolation in both `$"..."` and `$'...'`, and double-quoted strings interpret backslashes before the regex engine sees them. Keep the pattern in a single-quoted literal: `($label + ' (?<n>\d+)')`.
- **Quote list elements containing commas.** `[--sort=-pcpu,-pmem]` passes two arguments, so `ps` receives a separate `-pmem` and selects different rows.
- **String literals preserve source newlines and indentation.** Nushell has no backslash line continuation inside strings. Put prose in an adjacent Markdown file. For generated text, join explicit lines or fragments with the intended separator.
- **Argument-forwarding functions need `def --wrapped`.** With a plain `def`, `...args` leaves `--porcelain` subject to the wrapper's own flag parser. `def --wrapped name [...args: string] { ^command ...$args }` accepts undeclared flags and forwards them as arguments.

### External commands

- **Handle tolerated failures explicitly.** A nonzero external exit aborts execution. Use `try { ... }` or `| complete` and inspect `.exit_code`. `complete` accepts external-command output, so use `try` for fallible builtins.
- **Remove environment variables with `hide-env --ignore-errors`.** The removal reaches external children, allowing a fetch to bypass an inherited proxy.
- **Quote again when crossing a shell boundary.** List arguments retain their boundaries in `^command`, but `ssh` and `nix-shell --run` pass command text to another shell.
- **Read script stdin with `^cat`.** `$in` reads `nothing` under the generated shebang because `writeNu` does not add `--stdin`. Reopening `/dev/stdin` fails with ENXIO when the caller supplies a socket, as Node's `spawn` does, even though it works in a shell pipeline.
- **Keep output outside `par-each --keep-order`.** The flag preserves result order, but a `print` inside the block still interleaves across threads. Collect records and print afterwards.

## In Nix

`pkgs.writers.writeNu` produces a plain script and `writeNuBin` produces `$out/bin/<name>`. Both take an optional attrset as their second argument, after the name.

Keep checked-in Nushell valid on its own. Supply one or two scalar values as typed `main` arguments through `makeWrapperArgs` and `--add-flag`. For structured values, write one JSON config, inject its path the same way, and open it in `main`. Put ordinary executable dependencies on the wrapper's `PATH`.

Put model-facing prose in an adjacent `prompt.md`, or `<role>-prompt.md` when a hook needs more than one, and load it with `builtins.readFile`. Markdown formatting and prose checks can inspect these files but cannot inspect strings embedded in Nushell. `MD013` is off, so each paragraph stays on one line. Name the file for its role, since the directory already names the hook.

Both writers prepend an absolute-store-path shebang, which demotes a script's own `#!/usr/bin/env nu` line to a comment. Keep that line for standalone execution and LSP checks. For helpers invoked directly from the checkout, also commit the executable bit and call them by path. To spawn nushell from inside a generated script, read `$nu.current-exe` rather than substituting a store path.

A parse-time `use` target must resolve in both the source tree and the store output. Expose a helper as an executable when no stable module path exists in both places.

## Linting

`nu-check` (`packages/nu-check/`) wraps `nu --ide-check`. It gates delimiters and the arity of your own `def`s and little else, since a mistyped command name passes as an external call, so a script still needs one real run.

Indentation belongs to `editorconfig-checker`, which reads `.editorconfig` for every tracked file. `nufmt` is unused: it only joins lines, and it reindents to four spaces against the `[*.nu] indent_size = 2` in force here.

## What stays bash

Keep bash for scripts evaluated by another shell and for small process launchers:

- **A `--run` or sourced script.** `profile-loader.sh` and `mkProxyScript` are injected through `makeWrapper --run`, so the wrapper's own shell evaluates them. `teammate-launcher.sh` sources `profile-loader.sh`.
- **`exec` wrappers.** Setting a variable and handing off to the real binary has no data to structure. This covers the MCP wrappers, `notify`, and most of the remaining `writeShellScript` sites.

Hook errors leave the underlying tool call running, so a porting bug can silently disable the hook. Compare the old and new scripts on representative hook payloads before deleting the bash implementation.
