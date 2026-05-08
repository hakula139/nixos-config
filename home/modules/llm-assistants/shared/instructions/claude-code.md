## Session Patterns

Treat Claude Code as a capable engineer you delegate to. Avoid line-by-line steering.

- **Specify the task up front.** State intent, constraints, acceptance criteria, and relevant file locations in the first turn. Well-scoped first turns spend fewer tokens than progressively clarifying across many.
- **Batch questions.** Every user turn adds reasoning overhead. Collect clarifications and ask together.
- **Trust adaptive thinking.** The model decides per step whether to think. Skip scaffolding like `"think hard"` or `"summarize every N tool calls"`. When specific steering helps, state it positively (e.g., `"This problem is harder than it looks; think step by step"`).
- **Literal instruction following.** State scope explicitly (`"Apply to every section in the file"` rather than `"Apply this"`). Ambiguity gets scoped narrowly.

## Git Workflow

- Verify the current branch before committing. Switch first if a new branch was created.
- When preparing PRs, verify that the diff and commit count match expectations before pushing.
- **Wait for explicit per-PR approval before merging.** Earlier blanket approvals do not extend to PRs opened later in the session. After `gh pr create`, push, report the URL, and wait for `lgtm` or `merge` referencing that specific PR.
- **PR body authoring.** Prefer `gh pr edit --body-file <file>` or `gh pr create --body-file -` over inline `--body "$(cat <<'EOF' ... EOF)"`. The file-input form avoids shell-escape bugs around backticks and `$()` substitution. Either way, do not reference prior PRs as `#N` in the body. GitHub auto-expands them into title cards that break sentence flow.

## Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, since leading comments break permission pattern matching. Use the Bash tool's `description` parameter for explanations instead.

## MCP Server Usage

Prefer MCP tools over equivalent Bash commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Atlassian (`mcp__Atlassian__*`)

Scoped to Confluence. Search, read, and navigate pages, spaces, and hierarchies. Read operations are auto-approved. Writes require user confirmation.

### Brave Search (`mcp__BraveSearch__*`)

Fallback web search. Use when `WebSearch` fails, returns unhelpful results, or when a specialized search type is needed (news, images, video, local businesses). Supports result summarization.

### Codex (`mcp__Codex__*`)

Delegates self-contained, multi-step coding tasks to an autonomous agent. Codex runs with full shell access and its own MCP servers in a separate context window.

Use Codex when:

- A task requires autonomous multi-step work with shell commands.
- Offloading work to a separate context window is useful.
- An independent second opinion or alternative implementation path is valuable.

Do not use Codex when:

- Claude Code can handle the work directly with less overhead.
- The task depends heavily on the current conversation context.
- The work is just a quick one-shot command.

### DeepWiki (`mcp__DeepWiki__*`)

AI-powered documentation for public GitHub repositories. Use for unfamiliar repos: architecture, patterns, API design.

### Fetcher (`mcp__Fetcher__*`)

Browser-based web fetcher using Playwright. Fallback for when native web fetch is blocked (403 responses, bot protection) or the page requires JavaScript rendering. Supports content extraction and multi-URL fetching.

### Filesystem (`mcp__Filesystem__*`)

Structured file operations with directory sandboxing. Use for operations beyond native Read / Write / Edit tools: moving files, directory trees, reading multiple files at once, glob-based search. Sandboxed to allowed directories.

### Git (`mcp__Git__*`)

Structured git operations. Prefer over Bash `git` commands. They accept a `repo_path` parameter, keeping the working directory unchanged and avoiding permission pattern issues with `git -C`.

### GitHub (`mcp__GitHub__*`)

GitHub API for issues, PRs, code search, reviews, releases, and repository management. Prefer over `gh` CLI for structured responses and pagination.

### GitLab (`mcp__GitLab__*`)

GitLab API for issues, merge requests, pipelines, labels, and repository management. Prefer over `glab` CLI. Use `project_id` as the URL-encoded project path (e.g., `group/subgroup/project`).

### IDE (`mcp__ide__*`)

Use `getDiagnostics` to check for language server errors / warnings in files. Use `executeCode` for running Python code in Jupyter kernels when working with notebooks.

## Agent Team Workflow

Agents run in two modes:

- **Subagents**: focused workers that report only to the orchestrator. Use when agents do not need to talk to each other.
- **Agent Teams**: peer-to-peer coordination via shared task state and `SendMessage`. Use when agents need to share findings, challenge conclusions, or hand work off directly.

All agents inherit the parent tool set. Behavioral boundaries live in each agent's prompt. The exception is **codex-worker**, which keeps a narrower tool set so it actually delegates to Codex instead of doing the work itself.

### Available Agents

- **architect**: Architecture review, design critique, pattern analysis.
- **codex-worker**: Delegates self-contained tasks to Codex MCP.
- **debugger**: Hypothesis-driven debugging and root cause analysis.
- **implementer**: Code writing, feature implementation, refactoring.
- **researcher**: Codebase exploration and documentation lookup.
- **reviewer**: Code quality, security, bug detection.
- **tester**: Test writing, execution, failure analysis.
- **usability-reviewer**: Clarity and ergonomics review for user-facing surfaces.

### When to Use Agents

Subagents spawn conservatively by default. When parallel work genuinely helps, ask explicitly and describe the fan-out (e.g., `"launch parallel researchers across these three directories"`).

Use agents for parallelism across independent items, a specialist perspective, or to offload from a crowded context window. Skip them when the work fits in a single response, needs continuous user interaction, or the delegation overhead exceeds the benefit.

### Shared-Tree Safety

When multiple subagents share a working tree, `git stash`, `git checkout --`, `git reset --hard`, and `git clean -f` from any one of them can wipe the others' uncommitted work. Treat these as destructive whenever parallel writers exist.

- Brief every write-capable subagent that only `git status`, `git diff`, and `git log` are safe.
- Isolate genuinely parallel writers in their own worktrees (`Agent({ isolation: "worktree", ... })`).
- Before aborting a mid-flight agent, give it a chance to flush edits to a patch file under `/tmp/`.

### Coordination Patterns

- **Sequential pipeline** (Subagents): researcher → architect → implementer → reviewer → tester. Each agent's output feeds the next. See Feature Development Workflow below.
- **Feature dev** (Agent Team): full delivery pipeline with peer coordination. 1 researcher, 1 architect, 1–2 implementers, 1 reviewer, 1 tester. Task dependencies enforce ordering. Implementers use worktree isolation for parallel work.
- **Parallel fan-out**: multiple agents of the same role across independent areas (e.g., 3 reviewers with security / correctness / coverage lenses, or N researchers across subsystems). As **Subagents** they report independently and the orchestrator synthesizes. As an **Agent Team** they share discoveries and redirect each other.
- **Competing hypotheses**: debuggers chasing different theories. As **Subagents** each reports independently. As an **Agent Team** teammates actively challenge each other.
- **Review gate** (Subagent): reviewer after significant implementation changes.
- **Codex offloading** (Subagent): codex-worker for orthogonal tasks in a separate context window.

### Feature Development Workflow

Sequential pipeline for non-trivial features. Prevents wasted implementation effort.

1. **Explore** (optional): researcher gathers context on existing patterns. Skip for well-understood changes.
2. **Propose**: architect produces a "Design Proposal" with motivation, scope, approach, impact, risks.
3. **Decide**: present to the user. Approve, request changes, or reject before any code is written.
4. **Implement**: implementer works from the proposal and tracks multi-file progress via TaskCreate / TaskUpdate.
5. **Verify**: reviewer checks code quality AND plan adherence (completeness, coherence, scope discipline).
6. **Test**: tester works from the implementer's change summary and the reviewer's risk areas.

Steps 1–3 prevent building the wrong thing. Steps 5–6 catch both code defects and plan deviations.

## Context Compaction Guidance

When summarizing for compaction, preserve current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, re-read project CLAUDE.md files before continuing.
