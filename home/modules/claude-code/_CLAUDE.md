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

## Punctuation

Use spaces around `/` when separating distinct words (e.g., "Read / Write"). Omit spaces for abbreviations and compound terms (e.g., "I/O", "TCP/IP").

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

## Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, not a `# comment`. Use the Bash tool's `description` parameter for explanations instead. Shell comments in the command string break permission pattern matching (e.g., `Bash(git status:*)` won't match `# Check status\ngit status`).

## MCP Server Usage

Prefer MCP tools over equivalent Bash commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### DeepWiki (`mcp__DeepWiki__*`)

Use when exploring or asking questions about GitHub repositories — understanding project architecture, finding documentation, or getting context about how a codebase works. Particularly useful for unfamiliar open-source projects.

### Filesystem (`mcp__Filesystem__*`)

Available for file operations with built-in directory sandboxing. Use when the native Read / Write / Edit tools are insufficient or when you need operations like `move_file`, `directory_tree`, or `search_files` with glob patterns.

### Git (`mcp__Git__*`)

Prefer over Bash git commands when operating on repositories outside the current working directory. MCP Git tools accept a `repo_path` parameter, avoiding the `git -C` flag which bypasses Bash permission patterns.

For operations not covered by MCP Git (e.g., `git cherry-pick`, `git rebase`, `git stash`), ensure you're in the repository directory first.

### GitHub (`mcp__GitHub__*`)

Use for all GitHub API interactions — issues, pull requests, code search, repository management, and reviews. Prefer over `gh` CLI commands as MCP provides structured responses and proper pagination.

**Tool selection:**

- `list_*` tools for broad retrieval of all items (all issues, all PRs, all branches)
- `search_*` tools for targeted queries with specific criteria or keywords

**Read operations** (auto-approved): `get_*`, `list_*`, `search_*`, `issue_read`, `pull_request_read`

**Write operations** (require confirmation): `create_*`, `update_*`, `delete_*`, `merge_*`, `push_*`, issue / PR modifications

**Common workflows:**

- Always call `get_me` first to understand current user context
- Use `search_issues` before creating new issues to avoid duplicates
- For PR reviews: `pull_request_review_write` (create pending) → `add_comment_to_pending_review` → `pull_request_review_write` (submit)

### IDE (`mcp__ide__*`)

Use `getDiagnostics` to check for language server errors / warnings in files. Use `executeCode` for running Python code in Jupyter kernels when working with notebooks.

### Codex (`mcp__Codex__*`)

Use for delegating **self-contained, multi-step coding tasks** to an autonomous agent powered by GPT-5.3-codex. Codex runs with full shell access and its own MCP servers (Context7, DeepWiki, Filesystem, Git, GitHub), making it capable of independent exploration, code generation, and command execution.

**When to use Codex:**

- Tasks that require autonomous multi-step work with shell commands (e.g., refactoring across files, writing and running scripts, building and testing code)
- Offloading work to a separate context window — useful when Claude Code's context is already large or the task is orthogonal to the current conversation
- Leveraging GPT-5.3-codex's strengths for code generation or analysis
- Tasks where an independent second opinion or alternative approach is valuable

**When NOT to use Codex:**

- Simple file reads / edits that Claude Code can handle directly
- Tasks that depend heavily on the current conversation context (Codex starts fresh or continues its own thread)
- Quick one-shot commands — use Bash or other MCP tools directly instead

**Tools:**

- `codex` — Start a new session. Key parameters:
  - `prompt` (required): The task description
  - `cwd`: Working directory (defaults to server's cwd)
  - `model`: Override the default model if needed
  - `sandbox`: `read-only` | `workspace-write` | `danger-full-access`
  - `approval-policy`: `untrusted` | `on-failure` | `on-request` | `never`
- `codex-reply` — Continue an existing session using `threadId` from a previous response. Use this for follow-up instructions, corrections, or multi-turn workflows

**Session management:**

- Each `codex` call returns a `threadId` — preserve it if you plan to continue the conversation
- Use `codex-reply` with the `threadId` for iterative work rather than starting new sessions, to maintain context continuity
