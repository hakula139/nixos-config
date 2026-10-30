# Nushell

Nushell is the default for new helper scripts.

- **Entry point**: `def main` with typed parameters, so Nushell checks arity and types.
- **Script-relative resources**: bind `const SCRIPT_DIR = path self .` after the header and imports. It resolves at parse time from the defining file, so Nix must package those resources beside the script.
- **Help**: keep the script header to its purpose and operating constraints, and document usage at each command and parameter so `--help` carries it. Point to it with `Run with --help for usage.` only when the header says something else.
- **Multiline strings**: indent the literal with the code, with the opening quote, content, and closing quote at one column, then `| str dedent` from `std-rfc/str` on the next line and any enclosing parenthesis on its own line.

## What stays bash

- Scripts that another shell evaluates, such as `makeWrapper --run` snippets and sourced files.
- `exec` wrappers that only set a variable and hand off.

## Traps

These traps assume the Nushell Book's [Thinking in Nu](https://www.nushell.sh/book/thinking_in_nu.html) and [Coming from Bash](https://www.nushell.sh/book/coming_from_bash.html). Reproduce a trap on the pinned Nushell before adding it.

### Parsing and data

- **`from json` accepts some plain text, so `try` cannot validate JSON.**

  - `open` on an empty JSON, YAML, or NUON file returns null, while truncated JSON raises.
  - Check the shape (`$j | describe | str starts-with "record"`) before reading a field.

- **`get -o` raises on rows that are not records.** It tolerates a missing column but fails on a list of strings or a scalar, so wrap it in `try` when the shape is unverified.

- **Return annotations do not validate dynamic output.** A `-> record` function can return a list from an untyped helper, and `get -o` on an empty list returns `[]`, which `default` keeps.

- **A `mut` or a defaulted closure parameter takes the type of its initial value.** Each later value is checked against that type, at parse time when its type is known and at runtime otherwise, so `mut current = null` rejects a record, `mut n = 0` rejects a float, and `generate {|row, acc = null| ... }` raises `Can't convert to nothing` once it passes `acc` a value. Annotate the union, as in `mut current: oneof<record, nothing> = null`, because `nu-check` misses the runtime case.

- **YAML error messages hide the parser's detail.** Read `$e.rendered` in the catch block, since `$e.msg` says only `Error while parsing as yaml`.

- **`math sum` errors on an empty list.** Use `| append 0 | math sum`.

- **`open --raw` yields a byte stream, which collects to `binary` on invalid UTF-8.** A `: string` parameter or a `string ->` input then raises a type error. To require UTF-8, pipe the stream itself into `into string` inside `try`, which raises `Non-UTF8 string` on invalid bytes and on a UTF-16 BOM. `into string` rejects every collected `binary`, valid or not, so check bytes captured with `into binary` by comparing `$bytes | decode utf-8 | encode utf-8` with them after any leading UTF-8 BOM, since `decode utf-8` strips that BOM, replaces invalid bytes, and honors a UTF-16 BOM.

### Strings and arguments

- **Bare words depend on context.** `if $x { green }` calls a command named `green`, `where after != before` compares the `after` column with the string `"before"` (write `where after != $it.before`), and an untyped `1min` arrives as a duration while a `: string` parameter coerces it.

- **List elements containing commas need quotes.** `[--sort=-pcpu,-pmem]` passes two arguments.

- **Dynamic regexes need single-quoted pieces.** Parentheses interpolate in both `$"..."` and `$'...'`, and double quotes consume backslashes, so concatenate: `($label + ' (?<n>\d+)')`.

- **Forwarding arguments needs `def --wrapped`.** A plain `def` parses flags in `...args` itself.

### External commands

- **A nonzero external exit ends the script with that code and prints nothing.** Tolerate it with `try` or `| complete` and `.exit_code`.

- **Stdin needs `^cat`.**

  - `$in` is empty under the generated shebang, which lacks `--stdin`, and reopening `/dev/stdin` fails with ENXIO on a socket, as Node's `spawn` supplies.
  - Text capture strips one trailing newline, so use `^cat | into binary` for byte-identical round trips.

## In Nix

- **Inputs**: keep checked-in Nushell valid on its own.

  - Pass one or two scalars as typed `main` arguments with `makeWrapperArgs` and `--add-flag`.
  - Pass structured values as one JSON config file the same way.
  - Put executables on the wrapper's `PATH`.

- **Shebang**: the writers prepend a store-path shebang, which demotes the script's `#!/usr/bin/env nu` to a comment. Keep that line for standalone runs and LSP checks, and commit the executable bit on helpers run from the checkout. Spawn Nushell from a generated script with `$nu.current-exe`.

- **Modules**: a parse-time `use` target must resolve in both the source tree and the store. Without such a path, expose the helper as an executable.

## Testing

Give a script a `<script>.test.nu` beside it when its output is easy to get subtly wrong, such as a parser, an access decision, or a rewrite of user text. Drive it the way its caller does, and skip tests that only restate the code or need the external tools the script exists to call.

- **Tests**: commands named `test <behavior>` in plain words, asserting with `std/assert`.

- **Fixtures**: when several cases differ only in document-like or byte-sensitive inputs, make them golden files under `fixtures/<group>/<case>/`.

  - A `case.nuon` holds what the files cannot express. Write structured payloads in it as records, and single-quote strings that contain `"`. Write line breaks in its strings as `\n`. Lay it out like Nushell source, with each list item on its own line and a record broken one field per line when it would pass 100 columns.
  - Small structured inputs, such as argv lists and payload records, stay inline in the test.
  - Copy each input into a `mktemp` directory before running the script, so the script never writes to a fixture. The runner confines `mktemp` to a scratch `TMPDIR`.
  - Store fixtures are read-only and `cp` keeps the mode, so `chmod u+w` a copy the script writes.

- **Stubs**: a stand-in for an executable is `<executable>.stub.nu` beside the test, which the runner installs in `$env.NU_TEST_STUBS`. A stub that records calls appends JSON lines to `$env.STUB_LOG`, read back with `open $log | from json --objects`.

- **Running**: `nu-test <file>...` runs each test in its own process. A test needing tools beyond Nushell, bash, and coreutils adds them to the check's inputs.

- **Refactors and ports**: diff every fixture's or representative payload's output from the old script (`git show HEAD:<path>`) against the rewrite, running both under the wrapper's runtime `PATH` so a pre-existing bug does not read as a regression. Do this before porting a hook, since a hook error leaves the tool call running and silently disables the hook.

## Linting

`nu-check` wraps `nu --ide-check`, which catches delimiters and the arity of local `def`s but passes a mistyped command as an external call, so run the script once for real. `editorconfig-checker` owns indentation. Don't use `nufmt`, which reindents to four spaces.
