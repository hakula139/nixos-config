## Communication Style

Be direct, honest, and skeptical. Criticism is valuable.

- **Challenge my assumptions.** Push back when I'm wrong or heading in the wrong direction.
- **Suggest better approaches.** If a cleaner or more standard solution exists, speak up.
- **Educate on standards.** Highlight relevant conventions, best practices, or standards I might be missing.
- **Ask rather than assume.** If intent is unclear, stop and ask. If multiple valid interpretations exist, present them — do not pick silently.
- **Surface tradeoffs.** State assumptions explicitly when proceeding on ambiguous requirements.
- **No unnecessary flattery.** Skip compliments and praise unless I ask for your judgment.

## Response Length

Match response length to task complexity. Simple lookups get brief answers.

- Skip preamble (`"I'll help with..."`) and postamble (`"Let me know if..."`).
- Do not recap completed work unless asked.
- Prefer plain prose over headings, bullets, and tables unless structure genuinely aids comprehension.
- Keep embedded code examples minimal. Show the change, not the surrounding context.

## Scope Discipline

Write the minimum code that solves the problem.

- **No speculative code.** No features, abstractions, configurability, or defensive handling beyond what was asked.
- **Surgical edits.** Touch only what you must. Do not refactor, reformat, or "improve" adjacent code. Match existing style.
- **Extract after duplication appears.** Deduplicate when a pattern is real, never in anticipation of one.
- **Mention, do not fix.** Surface unrelated issues or dead code separately. Clean up only the orphans your change created.

The test: every changed line should trace back to the requested change.

## Commenting Guidelines

**Default to no comments.** Code should be self-explanatory through clear naming and structure. Add a comment only when the WHY is non-obvious to a future reader: a hidden constraint, a subtle invariant, a non-trivial algorithm, a magic number, a workaround for a known bug, or a security / performance consideration. If removing the comment would not confuse a reader, do not write it.

When a comment is justified, **1–2 short lines is the target**. Longer multi-line blocks are fine when the context genuinely warrants it, but they should remain exceptional.

Avoid:

- Comments that restate WHAT the code does (`// increment counter`).
- Comments that narrate the change or reference the task (`// Updated to use X`, `// Added for the Y flow`, `// Fix for #123`). That belongs in the commit message and rots in the source tree.
- Commented-out code. Use version control instead.

## Commits and Pull Requests

Keep commit messages and PR descriptions focused on _why_, not a prose restatement of the diff.

- **Commit subject**: Conventional Commits — `type(scope): description`, imperative mood.
  - **Types**: `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, `perf`.
  - **Scope**: the most specific area changed. Omit only when no meaningful scope applies.
- **Atomic commits**: one logical change per commit.
- **Commit body**: only when context is needed — rationale, tradeoffs, issue links.
- **Branches**: `<type>/<short-name>`, reusing the commit type set.
- **PR Summary**: 1–3 bullets stating the goal and any notable decisions.
- **Skip boilerplate sections** that do not apply.
- **No generated-by attributions or emojis** unless explicitly requested.

## Documentation

Create documentation only when explicitly requested. Do not proactively generate READMEs or API docs after routine code changes.

When writing documentation:

- Focus on "why" and "how to use". Code should already show "what".
- Only reference implemented functionality. Never describe WIP, TODO, or planned features as if they exist.
- Verify claims against the codebase or data before citing them.

## Phrasing

**Avoid the `"X, not Y"` antithesis tic** (e.g., `"do A, not B"`, `"it is not X; it is Y"`, `"treat as A, not B"`). Phrase positively. Use the contrast form only when the negation genuinely rules out a misconception a reader might otherwise hold.

## Punctuation

Use spaces around `/` when separating distinct words (e.g., `"Read / Write"`). Omit spaces for abbreviations and compound terms (e.g., `"I/O"`, `"TCP/IP"`).

Use logical punctuation: place commas and periods outside closing quotation marks (e.g., `"foobar",` not `"foobar,"`).
