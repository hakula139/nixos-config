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

## Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, not a `# comment`. Use the Bash tool's `description` parameter for explanations instead. Shell comments in the command string break permission pattern matching (e.g., `Bash(git status:*)` won't match `# Check status\ngit status`).

## MCP Server Usage

Prefer MCP tools over equivalent Bash commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

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

**Evaluating Codex output:**

- Treat Codex as a peer with its own knowledge cutoffs and blind spots — verify claims before accepting them, especially regarding recent APIs, library versions, or best practices
- When confident Codex is wrong, say so directly and provide evidence (own knowledge, web search, docs)
- If a disagreement warrants discussion, resume the session via `codex-reply` with the evidence and let the user decide when there's genuine ambiguity

### DeepWiki (`mcp__DeepWiki__*`)

Use when exploring or asking questions about GitHub repositories — understanding project architecture, finding documentation, or getting context about how a codebase works. Particularly useful for unfamiliar open-source projects.

### Fetcher (`mcp__Fetcher__*`)

**Fallback web fetcher** using Playwright headless browser. Use **only** when the native `WebFetch` tool fails with 403 or other blocking errors (Reddit, Wikipedia, npm, and other sites that reject the default `axios` user agent).

**Do NOT use as the primary fetch tool.** `WebFetch` is faster and lighter. Fetcher spawns a full Chromium instance per request — only reach for it after `WebFetch` has already failed on the target URL.

**Tools:**

- `fetch_url` — Fetch a single URL. Key parameters:
  - `url` (required): Target URL
  - `timeout`: Page load timeout in ms (default: 30000)
  - `waitUntil`: Navigation completion event — `load` | `domcontentloaded` | `networkidle` | `commit` (default: `load`)
  - `extractContent`: Intelligently extract main content (default: true). Set to `false` for complete page content
  - `returnHtml`: Return HTML instead of Markdown (default: false)
  - `waitForNavigation`: Wait for additional navigation after initial load — useful for sites with anti-bot verification (default: false)
  - `navigationTimeout`: Max wait for additional navigation in ms (default: 10000)
  - `maxLength`: Max returned content length in characters (default: no limit)
  - `disableMedia`: Block images, stylesheets, fonts, media (default: true)
- `fetch_urls` — Batch fetch multiple URLs in parallel using multi-tab concurrency. Same parameters as `fetch_url` but takes `urls` (array) instead of `url`
- `browser_install` — Install Playwright Chromium binary. Use when fetch fails due to missing browser

**Handling tricky sites:**

- Anti-bot / CAPTCHA sites: Use `waitForNavigation: true` with increased `navigationTimeout`
- Slow-loading sites: Increase `timeout` (e.g., 60000)
- Failed content extraction: Set `extractContent: false` to get the full page
- Need raw HTML: Set `returnHtml: true`

### Filesystem (`mcp__Filesystem__*`)

Available for file operations with built-in directory sandboxing. Use when the native Read / Write / Edit tools are insufficient or when you need operations like `move_file`, `directory_tree`, or `search_files` with glob patterns.

### Git (`mcp__Git__*`)

Prefer MCP Git tools for all git operations, both in the current working directory and in other repositories. They accept a `repo_path` parameter, keeping the working directory unchanged and avoiding `git -C` which bypasses Bash permission patterns.

**Important**: These tools are NOT raw git commands. Parameters are simple values — do NOT use git CLI range syntax (e.g., `main...branch`). Pass plain refs instead.

**Tools:**

- `git_status`: `repo_path`
- `git_diff_unstaged`: `repo_path`, `context_lines` (optional, default 3)
- `git_diff_staged`: `repo_path`, `context_lines` (optional, default 3)
- `git_diff`: `repo_path`, `target` (a single ref: branch name, commit hash, or tag — NOT range syntax like `A...B`), `context_lines` (optional, default 3)
- `git_log`: `repo_path`, `max_count` (optional), `start_timestamp` / `end_timestamp` (optional, ISO 8601 or relative like "2 weeks ago")
- `git_show`: `repo_path`, `revision` (single ref)
- `git_commit`: `repo_path`, `message`
- `git_add`: `repo_path`, `files` (array of paths)
- `git_reset`: `repo_path`, `files` (optional array — if empty, resets all staged)
- `git_create_branch`: `repo_path`, `branch_name`, `start_point` (optional)
- `git_checkout`: `repo_path`, `branch_name`
- `git_branch`: `repo_path`, `branch_type` (`"local"` | `"remote"` | `"all"`), optional `contains` / `not_contains` filters

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

## Agent Team Workflow

Custom agents are available for delegation when tasks benefit from specialization or parallelism. Agents support two modes: **subagents** (lightweight, report back only) and **Agent Teams** (full peer coordination).

### Available Agents

All agents inherit the full tool set from the parent session (MCP servers, web access, IDE diagnostics, etc.). Behavioral boundaries are enforced by each agent's prompt, not tool restrictions. The exception is **codex-worker**, which has an explicit restricted tool list to force delegation to Codex.

- **architect** — Architecture review, design critique, pattern analysis. Read-only (by prompt, not tool restriction).
- **codex-worker** — Delegates self-contained tasks to Codex MCP for independent parallel work. Restricted tool list: Read, Grep, Glob, Bash, Codex MCP, Git MCP, IDE diagnostics.
- **implementer** — Code writing, feature implementation, refactoring.
- **researcher** — Codebase exploration and documentation lookup. Focused on fast context gathering. Read-only.
- **reviewer** — Code quality, security, and bug detection. Read-only. Optional Codex second opinion when Codex MCP is available.
- **debugger** — Hypothesis-driven debugging and root cause analysis. Read-only.
- **tester** — Test writing and execution, failure analysis.
- **usability-reviewer** — Usability and clarity review from a non-expert perspective. Evaluates user-facing surfaces (APIs, docs, error messages, CLI help text) for intuitiveness — does NOT overlap with the reviewer's focus on internal code quality. Read-only.

### Subagents vs Agent Teams

**Subagents** (`Task` tool without `team_name`): Focused, independent workers that report results back to the orchestrator only. Cheaper, simpler, and sufficient when agents don't need to communicate with each other.

**Agent Teams** (`TeamCreate` + `Task` with `team_name`): Full peer-to-peer coordination via shared task list and `SendMessage`. Use when agents need to share findings, challenge each other's conclusions, or hand off work directly (e.g., reviewer sends issues to implementer without routing through the lead).

**Decision rule**: If agents need to talk to each other → Agent Team. If they just report back → subagents.

### When to Use Agents

Use the Task tool to delegate to agents when:

- A task benefits from **parallel work** (e.g., researcher gathers context while implementer writes code)
- The task is **self-contained** and doesn't need back-and-forth with the user
- You want a **focused perspective** (e.g., architect reviews design before implementation begins)
- **Context is getting large** — offload independent sub-tasks to preserve main context

### When NOT to Use Agents

- Simple, single-step operations you can handle directly
- Tasks requiring continuous user interaction
- When the overhead of delegation exceeds the benefit

### Model Selection

Agents inherit the parent model (opus) by default. Only override when a lighter model suffices:

- **opus** (default): architect, implementer, reviewer, usability-reviewer, debugger — tasks requiring deep reasoning, nuanced judgment, or complex analysis
- **sonnet**: tester — test writing is more pattern-following; speed matters in iterative test cycles
- **haiku**: researcher (simple lookups), codex-worker (delegation only)

### Coordination Patterns

**Sequential pipeline**: researcher → architect → implementer → reviewer → tester
**Parallel exploration**: Launch multiple researchers to explore different areas simultaneously
**Review gate**: Always run reviewer after implementer completes significant changes
**Codex offloading**: Use codex-worker for orthogonal tasks that benefit from a separate context window
**Bug investigation**: Spawn debugger(s) to investigate — optionally multiple with different hypotheses in parallel

### Agent Team Patterns

**Parallel review**: Spawn multiple reviewers with different lenses (security, performance, correctness) to review the same code simultaneously. The lead synthesizes findings.
**Implement-review loop**: Spawn implementer and reviewer as teammates. The implementer messages the reviewer directly after making changes; the reviewer sends issues back without routing through the lead.
**Research swarm**: Spawn multiple researchers to investigate different aspects of a problem. They share findings with each other via `SendMessage` and converge on an answer.
**Multi-hypothesis debugging**: Spawn multiple debuggers, each investigating a different hypothesis. They share confirming / contradicting evidence with each other and converge on a root cause.

### Team Presets

Pre-configured team compositions for common workflows. Use these as starting points when the user requests team-based work.

- **Review** — Thorough multi-angle code review before merging significant changes.
  - Teammates: 2-3 reviewer instances, each given a specific lens (e.g., "security focus", "correctness focus", "style / consistency focus") in their task description. For user-facing changes, include a usability-reviewer instance alongside the code reviewers.
  - The lead synthesizes findings into a single unified report.
  - Model: opus for all reviewers.

- **Debug** — Parallel hypothesis investigation for unclear bugs.
  - Teammates: 2-3 debugger instances, each assigned a distinct hypothesis to investigate.
  - Debuggers share confirming / contradicting evidence with each other via `SendMessage`.
  - The lead evaluates convergence and reports the most likely root cause.
  - Model: opus for all debuggers.

- **Feature** — End-to-end feature development with review gate.
  - Teammates: researcher + architect + implementer + reviewer.
  - Pipeline: researcher gathers context → architect designs approach → implementer writes code → reviewer validates.
  - Use task dependencies (`addBlockedBy`) to enforce ordering.
  - Model: haiku for researcher, opus for architect / implementer / reviewer.

- **Refactor** — Safe large-scale restructuring.
  - Teammates: architect + implementer + reviewer.
  - Architect analyzes current structure and proposes changes → implementer executes → reviewer verifies no regressions.
  - File ownership is critical: partition files between implementer instances if the refactor spans many files.
  - Model: opus for all.

### File Ownership in Teams

When running Agent Teams, avoid file conflicts by assigning distinct file sets to each teammate. Two teammates editing the same file leads to overwrites. The lead should partition work so each teammate owns different files.

### Agent Output Contract

All agents follow a shared output contract:

- **Status line**: Every report ends with `Status: completed | partial (<what remains>) | blocked (<what's needed>)`
- **Output budget**: Agents cap their output (150-200 lines) to preserve orchestrator context
- **File references**: All code-reading agents include `file:line` references for traceability
- **Escalation**: Agents report blockers rather than producing low-quality output or failing silently. This includes both task-level issues (scope too broad, ambiguous requirements) and infrastructure issues (tool failures, MCP timeouts, unreachable services). Always include the specific error or symptom — "Codex MCP returned timeout after 30s" is actionable; "couldn't complete the task" is not.
- **Prior context**: Agents build on upstream findings instead of re-investigating
- **Scratch files**: Agents that need working memory across tool calls write to `/tmp/claude-code/<project>/<agent>/<topic>.md`. The orchestrator can direct a replacement agent to read another's scratch files at this path if work needs to be picked up

In **team mode**, agents additionally:

- **Claim tasks** from the shared task list via `TaskList` / `TaskUpdate`
- **Send findings** to the lead and relevant peers via `SendMessage`
- **Stay available** by checking `TaskList` for more work after completing a task

## Context Compaction Guidance

When summarizing this conversation for compaction, preserve the following:

- **Current task state**: What is being worked on, what has been completed, what remains
- **Modified files**: The full list of files that have been created or changed
- **Architecture decisions**: Any design choices or trade-offs discussed during the session
- **Code style requirements**: Formatting rules, linting conventions, project-specific patterns
- **Unresolved issues**: Any open questions, blockers, or known problems not yet addressed

After compaction, re-read CLAUDE.md files to restore project conventions before continuing work.
