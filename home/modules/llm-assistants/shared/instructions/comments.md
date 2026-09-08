**Write comments that help maintain the code.** Use clear naming and structure, and add concise explanations of intent, constraints, invariants, tradeoffs, or surprising behavior that a future maintainer would otherwise have to rediscover. Usually **1–2 short lines suffice**, with more detail when the reasoning requires it. Follow the comment and section-banner conventions found during inspection.

**Docstrings explain contracts according to the project's conventions.** Document non-obvious constraints, units, ownership, errors, or invariants where callers need them. Keep the explanation concise, and omit text that merely restates the item name or implementation.

**Preserve useful rationale.** Within the scope of an edit, remove comments that repeat the code and correct those that have become misleading. Investigate an uncertain comment before deleting it, because the constraint it records may still apply.

**Align trailing comments in directory trees and similar listings.** Put comment markers in one column, leaving several spaces after the longest entry so small name changes do not shift every comment.

Avoid these patterns for the reasons below:

- **Comments that restate WHAT the code does** (`// increment counter`), or **describe the shape, order, or layout** of the code below them (`# Required fields first`). The reader can already see all of this, so the comment adds a second place to keep current and no information. Sorting or grouping is never on its own a reason to leave a comment.
- **Comments that narrate the change or reference the task** (`// Updated to use X`, `// Fix for #123`, `# Switched to a record because the user asked`, `# Fixed a bug where the counter double-incremented`). A future reader needs the code's present shape, and its edit history is noise to them. Version control already records why it changed, so this rots in the source tree while the commit message stays accurate. Resolving an issue or meeting a requirement is not on its own a reason to leave a comment.
- **Comments explaining a WHY a competent reader could already infer.** Being a "why" earns nothing on its own, since the test is whether the reason survives being deduced from the code. The reason has to be genuinely non-obvious.
- **A durable project rule stated at one call site.** It belongs in the instruction file or the documentation that owns it, where it applies everywhere and gets maintained once.
- **Commented-out code.** Version control preserves it without leaving a reader to guess whether it is pending, broken, or forgotten.

These comments also serve a purpose:

- **The meaning of a cryptic flag, literal, or API quirk** a reader could not recover without going to external documentation, such as what a flag does to a squash merge or why a unit is `oneshot`.
- **A nushell comment directly above a `def`**, which Nushell renders as the command's `--help` text, so deleting it blanks the CLI documentation.
- **A label naming the construct a non-obvious regex matches.** Restating the pattern in words is the one case where WHAT earns its place, since nobody reads `[=*_-]{4,}\s*$` as "a run of rule characters to end of line" without stepping through it character by character.
- **A section banner** helps readers navigate distinct groups of code. Preserve and add banners where surrounding or comparable files use them, including nested sections when that is the convention. Use short labels (`# Module options`, `# Formatter configuration`) and match the existing decoration. Explanatory sentences in a file header still follow the ordinary comment rules.
