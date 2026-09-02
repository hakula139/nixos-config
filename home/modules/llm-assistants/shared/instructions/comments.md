**Default to no comments.** Code should be self-explanatory through clear naming and structure. Add a comment only when the WHY is non-obvious to a future reader: a hidden constraint, a subtle invariant, a non-trivial algorithm, a magic number, a workaround for a known bug, behavior that would surprise a reader, or a security / performance consideration. If removing the comment would not confuse a reader, do not write it. When one is justified, **1–2 short lines is the target**.

**Docstrings follow the same discipline and the project's convention.** Check whether surrounding code uses them, and if the project has few or none, add none. When one is warranted, keep it to a line or two of non-obvious contract: a constraint, unit, ownership, error, or invariant. A docstring that restates the item name, documents a trivial getter, or rambles across several lines is verbose, so drop or trim it.

**When in doubt, delete.** Removing a comment that could have stayed is cheaper than keeping one that should have gone. Prune freely unless the user asked to keep that specific comment.

Each ban below carries its reason, because a rule stated without one gets satisfied on the surface while the underlying habit finds a new outlet.

- **Comments that restate WHAT the code does** (`// increment counter`), or **describe the shape, order, or layout** of the code below them (`# Required fields first`). The reader can already see all of this, so the comment adds a second place to keep current and no information. Sorting or grouping is never on its own a reason to leave a comment.
- **Comments that narrate the change or reference the task** (`// Updated to use X`, `// Fix for #123`, `# Switched to a record because the user asked`, `# Fixed a bug where the counter double-incremented`). A future reader needs the code's present shape, and its edit history is noise to them. Version control already records why it changed, so this rots in the source tree while the commit message stays accurate. Resolving an issue or meeting a requirement is not on its own a reason to leave a comment.
- **Comments explaining a WHY a competent reader could already infer.** Being a "why" earns nothing on its own, since the test is whether the reason survives being deduced from the code. The reason has to be genuinely non-obvious.
- **A durable project rule stated at one call site.** It belongs in the instruction file or the documentation that owns it, where it applies everywhere and gets maintained once.
- **Commented-out code.** Version control preserves it without leaving a reader to guess whether it is pending, broken, or forgotten.

A comment does earn its place when it carries information the code cannot:

- **The meaning of a cryptic flag, literal, or API quirk** a reader could not recover without going to external documentation, such as what a flag does to a squash merge or why a unit is `oneshot`.
- **A nushell comment directly above a `def`**, which Nushell renders as the command's `--help` text, so deleting it blanks the CLI documentation.
- **A label naming the construct a non-obvious regex matches.** Restating the pattern in words is the one case where WHAT earns its place, since nobody reads `[=*_-]{4,}\s*$` as "a run of rule characters to end of line" without stepping through it character by character.
- **A section banner**, which names code instead of describing it. A banner is a bare label of at most four words with no verb and no sentence (`# Module options`, `# Formatter configuration`), whether or not it is wrapped in a rule of repeated `=`, `*`, `_`, or `-` characters. The exemption covers that label line alone. Every sentence in a file header has to earn its place as an ordinary comment, and a comment describing an ordering is never a banner.
