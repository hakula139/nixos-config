# Documentation

Rules for repository documentation, rule placement, and claim verification. Follow [Writing](writing.md) for prose, Markdown, and punctuation.

## Content

Before editing documentation, identify what specifically needs correction or removal: claims or instructions made inaccurate by the change, or material that is obsolete or unnecessary. A new feature alone does not warrant expanding an overview. Create new documentation only when asked.

- Describe current, implemented behavior and usage. Put change summaries, the reasons behind editorial choices, and comparisons with removed or rejected approaches in commit or PR / MR descriptions, unless migration instructions need them or a design document records a rejected alternative whose reason still constrains the current design.
- Focus on why and how to use the feature. Give readers what they need to decide or act, and omit incidental details or facts already clear from the code.
- For an agent-facing procedure, use prose for steps whose commands the reader can derive. Reserve code blocks for text the reader should copy verbatim, and omit guidance for rare one-off tasks.

## Rule Placement

- Every preference in a guide must trace to the user's own statements. Reviewers may improve wording, flag contradictions, or check facts. They should use domain expertise to challenge a conflicting preference. When the user defers to that expertise, they should research established public practices and choose on their merits.
- State each rule once, in one home that other pages link to. Add an example only when the rule would otherwise be ambiguous. Omit cases and data points a capable model can infer from the rule, while preserving every rule and qualification. Add a rule to a repository's instructions or convention docs only when the code, tools, and history cannot show it, when it guards a destructive action, or when it has already cost a debugging session.
- State a rule no tool enforces with the goal it serves, so a reader can apply it to cases it does not name.
- Keep a repository's `AGENTS.md` to what applies to every task, with area rules in the docs it routes to, and keep its README for people evaluating or operating the project.
- Keep skills and docs that describe a general mechanism generic. Wiring in a new tool, package, or pin does not warrant naming it there.

## Verification

- Verify claims against the codebase or data before citing them. Before calling a referenced path stale, resolve it relative to the file that contains it and open that target.
