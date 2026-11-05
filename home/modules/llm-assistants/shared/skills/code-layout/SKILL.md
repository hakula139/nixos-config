---
name: code-layout
description: >-
  Lay out code for the reader and for one-line diffs. Use when writing, editing, or reviewing
  code or configuration in any language, including one-line edits, even when the request does
  not mention layout.
---

# Code Layout

Lay code out for the reader and for one-line diffs. Where a formatter decides, its decision wins.

## Line breaks

- Wrap code and comments at the project's line limit for the language, or at 100 columns where none is set, counting the indent. Hand-wrap comments, since formatters rarely reflow them, and keep a one-line string literal, and a table row holding one, whole at any length.
- Keep each table row, and each record in a list of like records, on one line.
- An external call or argument list with two or more options, bare flags included, keeps its command, subcommands, and positionals on the first line and puts each option with its value on its own line one level deeper, in the order its parser requires. A flag that selects the command's mode, as in `install -d`, belongs with the command like a subcommand, and a clustered bundle such as `tar -czf` stays whole. Options the parser needs before a subcommand nest under the command, with the subcommand line after them. A call with at most one option, and a builtin's switches, stay on one line.
- A wrapped command starts a deeper line, with its own options nested under it.
- Split an argument expression joined by operators the way you split options, keeping each parenthesized group, and each negation with its test, together.
- In a split call, a redirection takes its own line after the last option, and a trailing `|| ...` or `&& ...` starts its own line with the operator first, like the next stage of a pipeline, while a one-line call keeps them inline. Order-dependent redirections stay together.
- Give a data pipeline one stage per line, keeping a short accessor chain whole.
- Put each branch of a multi-branch construct on its own lines, except a short two-way choice between plain values, which reads as a ternary.

## Blank lines and order

- Separate distinct blocks and sibling groups with a blank line, and keep closely related code and single-line siblings together. Where a long sequence's boundaries would otherwise blur, set off a multiline statement, field, or entry with blank lines, unless a related single-line sibling leads into it. A short set or list stays one block even when an entry spans a few lines.
- Once one branch holds a blank line, put a blank line between all branches.
- An entry added to an existing sequence follows the spacing and grouping its siblings use.
- Order parameters and fields for readability: group related items, put dependencies before dependents, fall back to alphabetical order, and let API and project conventions win.

## Embedded code and text

- Keep standalone helper programs, test support programs, code templates, and substantial prompts in separate files with their language's extension, so formatters and linters check them.
- Write multiline prompts, messages, and embedded documents with literal line breaks, indented with the code, and strip that indentation with the language's native support or a standard helper, keeping relative indentation. Escapes stay fine for delimiters and programmatic string operations.

## Section banners

Banners end at the line limit, counting the indent. Where a project has no banner style of its own, use equals signs for the unindented file header and dashes for inner subsections, indented to match the surrounding code:

```nix
# ==================================================================================================
# Module Name
# ==================================================================================================

      # --------------------------------------------------------------------------------------------
      # Subsection
      # --------------------------------------------------------------------------------------------
```

Place a file description inside the header banner after the title, and close it with a third line of equals signs.
