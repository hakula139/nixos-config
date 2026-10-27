# Nushell

Nushell is the default for new helper scripts, since most of them parse an external tool's JSON and reshape it. Substantial scripts live in adjacent `.nu` files loaded with `builtins.readFile`, same as [bash](shell.md).

- **Entry point**: `def main` with typed parameters, so Nushell checks arity and types.
- **Script-relative resources**: bind `const SCRIPT_DIR = path self .` after the header and imports. It resolves at parse time from the defining file, so Nix must package those resources beside the script.
- **Help**: keep the script header to its purpose and operating constraints, and document usage at each command and parameter so `--help` carries it. Point to it with `Run with --help for usage.` only when the header says something else.

## Traps

### Parsing and data

- **`try` catches errors, `default` catches null.**

  - `open` on an empty file returns null, `from json` accepts some plain text as a string, and truncated JSON raises.
  - Check the shape (`$j | describe | str starts-with "record"`) before reading a field.

- **`get -o` raises on rows that are not records.** It tolerates a missing column but fails on a list of strings or a scalar, so wrap it in `try` when the shape is unverified.

- **Return annotations do not validate dynamic output.** A `-> record` function can return a list from an untyped helper, and `get -o` on a list returns `[]`, which `default` keeps. Count rows with `where ... | length`.

- **`loop` is typed as `nothing`.** A `-> string` function cannot end in one, so drop the annotation or use a pipeline.

- **YAML error messages hide the parser's detail.** Read `$e.rendered` in the catch block, since `$e.msg` says only `Error while parsing as yaml`.

### Strings and arguments

- **Bare words depend on context.** `if $x { green }` calls a command named `green`, and an untyped `1min` arrives as a duration while a `: string` parameter coerces it.

- **List elements containing commas need quotes.** `[--sort=-pcpu,-pmem]` passes two arguments.

- **Dynamic regexes need single-quoted pieces.** Parentheses interpolate in both `$"..."` and `$'...'`, and double quotes consume backslashes, so concatenate: `($label + ' (?<n>\d+)')`.

- **String literals keep source newlines and indentation, with no line continuation.**

  - Put prose in an adjacent Markdown file.
  - Indent a multiline literal with the code and pipe it through `str dedent` from `std-rfc/str`. Put the opening quote, content, and closing quote at one column, `| str dedent` on the next line, and an enclosing parenthesis on its own line.
  - Keep a single-line message as one literal at any length, without `+`.

- **Forwarding arguments needs `def --wrapped`.** A plain `def` parses flags in `...args` itself.

### External commands

- **A nonzero exit aborts the script.** Tolerate it with `try` or `| complete` and `.exit_code`. `complete` takes only external output, so use `try` for builtins.

- **Shell boundaries need a second round of quoting.** `^command` keeps list arguments intact, but `ssh` and `nix-shell --run` pass command text to another shell, which splits it again.

- **`hide-env --ignore-errors` reaches external children.** It can drop an inherited proxy for one fetch.

- **Stdin needs `^cat`.**

  - `$in` is empty under the generated shebang, which lacks `--stdin`, and reopening `/dev/stdin` fails with ENXIO on a socket, as Node's `spawn` supplies.
  - Text capture strips one trailing newline and a leading BOM, so use `^cat | into binary` for byte-identical round trips.
  - `decode utf-8` replaces invalid bytes and honors a UTF-16 BOM, so compare its re-encoding with the bytes to require UTF-8.

- **`par-each --keep-order` orders results but not `print`s.** Collect records and print afterwards.

## In Nix

- **Inputs**: keep checked-in Nushell valid on its own.

  - Pass one or two scalars as typed `main` arguments with `makeWrapperArgs` and `--add-flag`.
  - Pass structured values as one JSON config file the same way.
  - Put executables on the wrapper's `PATH`.

- **Prompts**: put model-facing prose in an adjacent `prompt.md`, or `<role>-prompt.md` when there are several, loaded with `builtins.readFile`, so Markdown and prose checks can see it.

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

- **Running**: `nu-test <file>...` runs each test in its own process. `checks.<system>.scripts` finds every `*.test.nu`, and a test needing tools beyond Nushell, bash, and coreutils adds them to the check's inputs.

- **Guard check**: before keeping a test, break the behavior it guards and confirm that it fails.

## Linting

`nu-check` wraps `nu --ide-check`, which catches delimiters and the arity of local `def`s but passes a mistyped command as an external call, so run the script once for real. `editorconfig-checker` owns indentation. Don't use `nufmt`, which reindents to four spaces.

## What stays bash

- Scripts that another shell evaluates, such as `makeWrapper --run` snippets and sourced files.
- `exec` wrappers that only set a variable and hand off.

When porting a hook, compare the old and new scripts on representative payloads first, since a hook error leaves the tool call running and silently disables the hook.
