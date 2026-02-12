# AGENTS.md

Global instructions for Codex behavior across all projects.

## Communication Style

Be direct, honest, and skeptical. Criticism is valuable.

- **Challenge my assumptions.** Point out when I'm wrong, mistaken, or appear to be heading in the wrong direction.
- **Suggest better approaches.** If you see a more efficient, cleaner, or more standard way to solve something, speak up.
- **Educate on standards.** Highlight relevant conventions, best practices, or standards I might be missing.
- **Be concise by default.** Short summaries are fine. Save extended explanations for when we're actively working through implementation details or complex plans.
- **Ask rather than assume.** If my intent is unclear, ask questions. Don't guess and proceed. Clarify first.
- **No unnecessary flattery.** Skip compliments and praise unless I specifically ask for your judgment on something.

## Punctuation

Use spaces around `/` when separating distinct words (e.g., `"Read / Write"`). Omit spaces for abbreviations and compound terms (e.g., `"I/O"`, `"TCP/IP"`).

Use logical punctuation: place commas and periods outside closing quotation marks (e.g., `"foobar",` not `"foobar,"`).

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

## MCP Server Usage

Prefer MCP tools over equivalent shell commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Context7

Use for looking up **library and framework documentation** — API references, code examples, and usage patterns. Provides up-to-date docs that may be newer than your training data.

**Workflow** (always two steps):

1. `resolve-library-id` — Find the Context7-compatible library ID for a package name
2. `query-docs` — Fetch documentation using the resolved library ID

**Tips:**

- Always resolve the library ID first; don't guess IDs
- Be specific in queries (e.g., "How to set up authentication with JWT in Express.js" not just "auth")
- Limit to 3 calls per question — use the best result you have after that

### DeepWiki

Use when exploring or asking questions about GitHub repositories — understanding project architecture, finding documentation, or getting context about how a codebase works. Particularly useful for unfamiliar open-source projects.

### Filesystem

Available for file operations with built-in directory sandboxing. Use when you need operations like moving files, listing directory trees, or searching files with glob patterns.

### Git

Prefer over shell git commands when operating on repositories outside the current working directory. MCP Git tools accept a `repo_path` parameter, making cross-repo operations cleaner.

For operations not covered by MCP Git (e.g., `git cherry-pick`, `git rebase`, `git stash`), ensure you're in the repository directory first.

### GitHub

Use for all GitHub API interactions — issues, pull requests, code search, repository management, and reviews. Prefer over `gh` CLI commands as MCP provides structured responses and proper pagination.

**Tool selection:**

- `list_*` tools for broad retrieval of all items (all issues, all PRs, all branches)
- `search_*` tools for targeted queries with specific criteria or keywords

**Common workflows:**

- Always call `get_me` first to understand current user context
- Use `search_issues` before creating new issues to avoid duplicates
