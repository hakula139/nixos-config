**Default to no comment.** Add a comment only when future maintainers need a non-obvious constraint that the code and names cannot convey. Put investigation findings, source provenance, and task-specific caveats in the PR / MR description. Follow the existing comment and section-banner conventions whenever a comment is needed.

**Docstrings document contracts** according to the project's conventions. Include the non-obvious constraints, units, ownership, errors, or invariants callers need to know. Keep docstrings concise and avoid restating the item's name or implementation.

**Preserve useful rationale.** When editing, remove comments that repeat the code and correct misleading ones. Investigate uncertain comments before deleting them, since they may record a constraint that still applies.

**Align trailing comments** in directory trees and similar listings in one column, several spaces after the longest entry, so a small rename does not shift every comment.

Avoid:

- **Comments that restate what the code does or describe its shape, order, or layout** (`// increment counter`, `# Required fields first`). They add no information and create a second place to maintain. Sorting or grouping alone never warrants a comment.
- **Comments that narrate a change or reference the task** (`// Updated to use X`, `// Fix for #123`, `# Switched to a record because the user asked`). Readers need the code's current shape, while version control records its history. Resolving an issue or meeting a requirement alone never warrants a comment.
- **Comments explaining a reason a competent reader could infer.** Add the reason only when it cannot be deduced from the code.
- **A durable project rule stated at a single call site.** Put it in the instruction file or documentation that owns it.
- **Commented-out code.** Version control preserves it without leaving readers to wonder whether it is pending, broken, or forgotten.

Worth keeping:

- **The meaning of a cryptic flag, literal, or API quirk** that would otherwise require external documentation, such as what a flag does to a squash merge or why a unit is `oneshot`.
- **A Nushell comment directly above a `def`**, which Nushell renders as the command's `--help` text.
- **A label naming the construct matched by a non-obvious regex.** This is the case where stating what it matches earns a comment, since nobody reads `[=*_-]{4,}\s*$` as "a run of rule characters to end of line" without stepping through the pattern.
- **Section banners** where surrounding or comparable files use them, including nested sections when that is the convention. Use short labels (`# Module options`, `# Formatter configuration`) and follow the existing decoration. Explanatory sentences in a file header follow the usual comment rules.
