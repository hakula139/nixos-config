# CLAUDE.md

Global instructions for Claude Code behavior across all projects.

## Communication Style

Be direct, honest, and skeptical. Criticism is valuable.

- **Challenge my assumptions.** Point out when I'm wrong, mistaken, or appear to be heading in the wrong direction.
- **Suggest better approaches.** If you see a more efficient, cleaner, or more standard way to solve something, speak up.
- **Educate on standards.** Highlight relevant conventions, best practices, or standards I might be missing.
- **Be concise by default.** Short summaries are fine. Save extended explanations for when we're actively working through implementation details or complex plans.
- **Ask rather than assume.** If my intent is unclear, ask questions. Don't guess and proceed. Clarify first.
- **No unnecessary flattery.** Skip compliments and praise unless I specifically ask for your judgment on something.

## Code Quality Principles

Follow the DRY (Don't Repeat Yourself) principle.

Always look for opportunities to reuse code rather than duplicate logic. Factor out common patterns into reusable functions, modules, or abstractions.

## Documentation Philosophy

Create documentation only when explicitly requested.

Do not proactively generate documentation files (README, API docs, etc.) after routine code changes. Documentation should be intentional, not automatic.

When documentation is requested, make it:

- Clear and actionable
- Focused on "why" and "how to use" rather than "what" (which code should show)
- Up-to-date with the actual implementation

## Commenting Guidelines

Comment the WHY, not the WHAT.

Code should be self-explanatory through clear naming and structure. Add comments only when the code itself cannot convey important context:

When to add comments:

- **Complex algorithms** - Non-obvious logic that requires explanation of the approach
- **Business rules** - Domain-specific constraints or decisions that aren't apparent from code alone
- **Magic numbers** - Hardcoded values that need justification
- **Workarounds** - Temporary fixes, hacks, or solutions to known issues (explain why and link to issues if possible)
- **Performance / security considerations** - Critical optimizations or security-sensitive sections that need extra attention

When editing existing code:

- Preserve existing comments unless they're outdated or wrong
- Update comments if the code logic changes

Avoid:

- Comments that simply restate what the code does
- Obvious explanations that clutter the code
- Commented-out code (use version control instead)
