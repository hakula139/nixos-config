---
name: code-layout
description: >-
  Lay out code for the reader and for one-line diffs. Use when writing, editing, or reviewing
  code or configuration in any language, including one-line edits, even when the request does
  not mention layout.
---

# Code Layout

Lay code out for the reader and for one-line diffs. Where a formatter decides, its decision wins.

The rules below serve that goal, so apply each by reading the construct, and keep the existing layout where a change would not clearly read better. A layout sweep judges each site the same way, and a brief for one states the goal with the current layout as the default and asks for a before / after list. Settle an ambiguous case by judgment, since tightening a rule to cover it is the user's choice.

## Line breaks

- Wrap code and comments at the project's line limit for the language, counting the indent. Hand-wrap comments because formatters rarely reflow them, and keep a one-line string literal and any table row holding one unbroken at any length.
- Keep each table row, and each record in a list of like records, on one line.
- When an external call or argument list has two or more options (bare flags included), keep the command, subcommands, and positionals on the first line, and put each option with its value on its own line one level deeper in the order its parser requires. A mode-selecting flag like `install -d` stays with the command like a subcommand, and a clustered bundle such as `tar -czf` stays whole. Options that the parser requires before a subcommand nest under the command, followed by the subcommand line. Keep a call with at most one option, and a builtin's switches, on one line.
- A wrapped command starts a deeper line, with its own options nested under it.
- Split an argument expression joined by operators the way you split options, keeping each parenthesized group, and each negation with its test, together.
- In a split call, put each redirection on its own line after the last option, and put a trailing `|| ...` or `&& ...` on its own line starting with the operator, like the next stage of a pipeline. Keep both inline in a one-line call, and keep order-dependent redirections together.
- Give a data pipeline one stage per line, keeping a short accessor chain whole.
- Put each branch of a multi-branch construct on its own lines, except a short two-way choice between plain values, which reads as a ternary.

## Blank lines and order

- Separate distinct blocks and sibling groups with a blank line, and keep closely related code and single-line siblings together. Where a long sequence's boundaries would otherwise blur, set off a multiline statement, field, or entry with blank lines, unless a related single-line sibling leads into it. A short set or list stays one block even when an entry spans a few lines.
- Once one branch holds a blank line, put a blank line between all branches.
- An entry added to an existing sequence follows the spacing and grouping its siblings use.
- Order parameters and fields for readability: group related items, put dependencies before dependents, fall back to alphabetical order, and let API and project conventions win.
- Group tests by behavior in the order the code runs, and within each behavior put the normal case first, even where a guard checks an error case before it.

## Embedded code and text

- Keep standalone helper programs, test support programs, code templates, and substantial prompts in separate files with their language's extension, so formatters and linters check them.
- Write multiline prompts, messages, and embedded documents with literal line breaks, indented with the code, and strip that indentation with the language's native support or a standard helper, keeping relative indentation. Escapes stay fine for delimiters and programmatic string operations.
