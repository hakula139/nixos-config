---
name: nushell
description: >-
  Write, review, and debug Nushell scripts and tests. Use when a task touches a `.nu` file or
  Nushell behaves unexpectedly.
---

# Nushell

## Scripts

- **Entry point**: `def main` with typed parameters.
- **Help**: limit the script header to its purpose and operating constraints, and document usage at each command and parameter so `--help` carries it.
- **Quoting**: quote string values, including paths and path segments, so they read as data. Leave names, flags, subcommands, and a builtin's own words bare, as in `decode utf-8`. Leave a glob meant to expand bare, and build a home path from `$nu.home-dir` because a quoted `~` stays literal. Keep the quotes any word needs to stay a literal string, as in `"0700"` and `"1min"`.
- **Multiline strings**: align the opening quote, content, and closing quote at the same column, then place `| str dedent` from `std-rfc/str` on the next line and any enclosing parenthesis on its own line.
- **Custom commands**: their switches stay on one line, as a builtin's do, since Nushell parses them itself.

## Traps

These traps assume the Nushell Book's [Thinking in Nu](https://www.nushell.sh/book/thinking_in_nu.html) and [Coming from Bash](https://www.nushell.sh/book/coming_from_bash.html). Reproduce a trap on the pinned Nushell before adding it.

### Parsing and data

- **`from json` accepts some plain text, so `try` cannot validate JSON.** `open` on an empty JSON, YAML, or NUON file returns null, while truncated JSON raises, so check the shape (`$j | describe | str starts-with "record"`) before reading a field.
- **`get -o` raises on rows that are not records.** It tolerates a missing column but fails on a list of strings or a scalar, so wrap it in `try` when the shape is unverified.
- **`get <n>` and `last` run every item of a stream and drop errors from the items they skip.** An `exit` or `error make` in a closure on a skipped item is discarded and the script continues, so only output the closure printed first, such as a `die` helper's message, still appears. Take a match with `first`, which stops pulling once it has one item and returns null on an empty stream.
- **Return annotations do not validate dynamic output.** A `-> record` function can return a list from an untyped helper, and `get -o` on an empty list returns `[]`, which `default` keeps.
- **A `mut` or a defaulted closure parameter takes the type of its initial value.** Each later value is checked against that type, at parse time when its type is known and at runtime otherwise, so `mut current = null` rejects a record, `mut n = 0` rejects a float, and `generate {|row, acc = null| ... }` raises `Can't convert to nothing` once it passes `acc` a value. Annotate the union, as in `mut current: oneof<record, nothing> = null`, because a linter misses the runtime case.
- **YAML error messages hide the parser's detail.** Read `$e.rendered` in the catch block, since `$e.msg` says only `Error while parsing as yaml`.
- **`math sum` errors on an empty list.** Use `| append 0 | math sum`.
- **`into datetime` reads a bare integer as nanoseconds.** A Unix timestamp in seconds needs `into datetime --format '%s'`.
- **`update` binds a named closure parameter to the row, not the cell.** Read the cell value from `$in`, as in `update body { $in | append $line }`.
- **`open --raw` yields a byte stream, which collects to `binary` on invalid UTF-8**, so a `: string` parameter or a `string ->` input raises a type error. To require UTF-8, pipe the stream itself into `into string` inside `try`, which raises `Non-UTF8 string` on invalid bytes and on a UTF-16 BOM. `into string` rejects every collected `binary`, valid or not.

### Strings and arguments

- **Bare words depend on context.** `where after != before` compares the `after` column with the string `"before"` (write `where after != $it.before`), and a comma splits a list item, so `[--sort=-pcpu,-pmem]` holds two items. Inside a list, an operator is a bare word too, so `["a" + $x]` holds three elements. Write `[("a" + $x)]` or `[$"a($x)"]`.
- **Outside parentheses or a list, a newline ends the command.** Arguments continue across lines only inside parentheses or a list, binary operators continue only inside parentheses, and a line starting with `|` continues the pipeline. A line starting with `and ($b)` calls a command named `and`, so wrap the whole expression in parentheses.
- **Dynamic regexes need single-quoted pieces.** Parentheses interpolate in both `$"..."` and `$'...'`, and double quotes consume backslashes, so concatenate them: `($label + ' (?<n>\d+)')`.
- **Forwarding arguments needs `def --wrapped`.** A plain `def` parses flags in `...args` itself. `--wrapped` also passes `--help` through as an argument, so a command whose operands may start with `-` keeps a plain `def` and its callers pass `--`.
- **A script argument starting with `--` is spliced into `main` unquoted.** On the pinned Nushell, `escape_for_script_arg` inserts an argument that starts with `--` and has no `=` into the `main ...` source line without quoting it, even after `--`, so `command -- '--x;print INJECTED'` runs `print INJECTED`. Callers must pass operands that cannot start with `--`, such as absolute paths.
- **`url encode` escapes characters a URI keeps.** The default escapes every ASCII punctuation mark except `.`, `/`, and `:`, including the unreserved `-`, `_`, and `~`, and `--all` escapes those three as well. To match another encoder, pass only the characters it escapes through `url encode --all`.
- **`$nu.home-dir` ignores a `HOME` change inside the running Nushell.** It is fixed at startup, so code that runs after `$env.HOME = ...` or inside `with-env {HOME: ...}` in the same process reads `$env.HOME`. A child Nushell started with a new `HOME` sees it.
- **`str length` counts UTF-8 bytes by default.** `"中文字" | str length` returns 9 on the pinned Nushell. Pass `--chars` or `--grapheme-clusters` when a limit is written in characters.

### External commands

- **`cp` reports a refused read or write as `nu: <error>` and still succeeds.** Use `^cp` when that failure must raise an error.
- **A nonzero external exit ends the script with that code and prints nothing.** Tolerate it with `try`, or by using `| complete` and checking `.exit_code`.
- **Reading stdin requires `^cat`.** `$in` is empty under a shebang that lacks `--stdin`, and reopening `/dev/stdin` fails with ENXIO on a socket. Text capture strips one trailing newline, so use `^cat | into binary` for byte-identical round trips.

## Testing

Test a script with `std/assert` when its output is easy to get subtly wrong. Drive it the way its caller does, and skip tests that only restate the code or require the external tools the script exists to call.

- **Structured inputs**: write JSON and JSONL test inputs as Nushell records and lists, serialized with `to json` for JSON or `to json --raw` per line for JSONL.

- **Fixtures**: when several cases differ only in document-like or byte-sensitive inputs, store them as golden files under the project's fixture directory, with one directory per case.

  - A `case.nuon` file holds what the golden files cannot express. Write a line break as `\n`, except in a multi-line text string, which reads better as a multiline literal with continuation lines starting at column 0 because NUON preserves indentation as content. Format it like Nushell source, putting each list item on its own line.

  - Keep small structured inputs in the test file.

  - Copy each input into a `mktemp` directory before running the script so the script never writes to a fixture.

## Linting

`nu --ide-check` exits 0 even when it reports an error, printing diagnostics as JSON, so inspect the severities. Without a max-errors argument, it exits 1 before reading the file. Because it catches delimiter errors and local `def` arity mismatches but treats a mistyped command as an external call, run the script once for real.
