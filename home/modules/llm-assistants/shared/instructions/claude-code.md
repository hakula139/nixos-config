## Session Patterns

Claude Code runs with Opus 4.7 at `xhigh` effort. Treat it like a capable engineer you delegate to, not a pair programmer you steer line by line.

- **Specify the task up front.** State intent, constraints, acceptance criteria, and relevant file locations in the first turn. Well-scoped first turns produce stronger results and spend fewer tokens than progressively clarifying across many turns.
- **Batch questions.** Every user turn adds reasoning overhead. Collect clarifications and ask them together.
- **Trust adaptive thinking.** Opus 4.7 decides per step whether to think. Do not add scaffolding like `"think hard"` or `"summarize progress every N tool calls"`. If specific steering is needed, state it positively (`"This problem is harder than it looks; think step by step"`) rather than prescribing cadence.
- **Literal instruction following.** Opus 4.7 reads instructions literally. If an instruction should apply broadly, state the scope explicitly (`"Apply to every section, not just the first"`). Ambiguity will be scoped narrowly, not generalized.

## Git Workflow

- Verify the current branch before committing. If a new branch was created, switch to it before making commits.
- When preparing PRs, verify that the diff and commit count match expectations before pushing.

## Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, not a `# comment`. Use the Bash tool's `description` parameter for explanations instead. Shell comments in the command string break permission pattern matching.

## MCP Server Usage

Prefer MCP tools over equivalent Bash commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Atlassian (`mcp__Atlassian__*`)

Scoped to Confluence. Use for searching, reading, and navigating Confluence pages, spaces, and page hierarchies. Read operations are auto-approved. Write operations (create / update / delete pages, add comments / labels, upload attachments) require user confirmation.

### Brave Search (`mcp__BraveSearch__*`)

Fallback web search. Use only when the native `WebSearch` tool fails, returns unhelpful results, or when a specialized search type is needed (news, images, video, local businesses). Supports summarization of search results. Do not use as the primary search path — prefer `WebSearch` by default.

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

AI-powered documentation for public GitHub repositories. Use for understanding unfamiliar repos — architecture, patterns, API design. Query specific questions or browse the generated wiki structure.

### Fetcher (`mcp__Fetcher__*`)

Browser-based web fetcher using Playwright. Fallback for when native web fetch is blocked (403 responses, bot protection) or the page requires JavaScript rendering. Supports content extraction and multi-URL fetching.

### Filesystem (`mcp__Filesystem__*`)

Structured file operations with directory sandboxing. Use for operations beyond native Read / Write / Edit tools: moving files, directory trees, reading multiple files at once, glob-based search. Sandboxed to allowed directories.

### Git (`mcp__Git__*`)

Structured git operations. Prefer over Bash `git` commands — they accept a `repo_path` parameter, keeping the working directory unchanged and avoiding permission pattern issues with `git -C`.

### GitHub (`mcp__GitHub__*`)

GitHub API — issues, PRs, code search, reviews, releases, repository management. Prefer over `gh` CLI for structured responses and pagination.

### GitLab (`mcp__GitLab__*`)

GitLab API — issues, merge requests, pipelines, labels, repository management. Prefer over `glab` CLI. Use `project_id` as the URL-encoded project path (e.g., `group/subgroup/project`).

### IDE (`mcp__ide__*`)

Use `getDiagnostics` to check for language server errors / warnings in files. Use `executeCode` for running Python code in Jupyter kernels when working with notebooks.

## Agent Team Workflow

Agents run in two modes:

- **Subagents**: focused workers that report only to the orchestrator. Use when agents do not need to talk to each other.
- **Agent Teams**: peer-to-peer coordination via shared task state and `SendMessage`. Use when agents need to share findings, challenge conclusions, or hand work off directly.

All agents inherit the parent tool set. Behavioral boundaries live in each agent's prompt, not in hard tool restrictions — except **codex-worker**, which keeps a narrower tool set so it actually delegates to Codex instead of doing the work itself.

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

Opus 4.7 is more judicious about spawning subagents by default. When parallel work genuinely helps, ask for it explicitly — describe the fan-out shape (e.g., `"launch parallel researchers across these three directories"`).

Use agents when the task benefits from parallelism across independent items, a specialist perspective, or offloading from a crowded context window.

Do not use agents when the work fits in a single response (e.g., refactoring a function already visible in context), requires continuous user interaction, or the delegation overhead outweighs the benefit.

### Coordination Patterns

- **Sequential pipeline** (Subagents): researcher → architect → implementer → reviewer → tester. Each agent's output feeds the next. See Feature Development Workflow below.
- **Feature dev** (Agent Team): full delivery pipeline with peer coordination. 1 researcher, 1 architect, 1–2 implementers, 1 reviewer, 1 tester. Task dependencies enforce ordering; implementers use worktree isolation for parallel work.
- **Parallel fan-out**: multiple agents of the same role across independent areas (e.g., 3 reviewers with security / correctness / coverage lenses, or N researchers across subsystems). As **Subagents** they report independently and the orchestrator synthesizes; as an **Agent Team** they share discoveries and redirect each other.
- **Competing hypotheses**: debuggers chasing different theories. As **Subagents** each reports independently; as an **Agent Team** teammates actively challenge each other.
- **Review gate** (Subagent): reviewer after significant implementation changes.
- **Codex offloading** (Subagent): codex-worker for orthogonal tasks in a separate context window.

### Feature Development Workflow

Sequential pipeline for non-trivial features. Prevents wasted implementation effort.

1. **Explore** (optional): researcher gathers context on existing patterns. Skip for well-understood changes.
2. **Propose**: architect produces a "Design Proposal" with motivation, scope, approach, impact, risks.
3. **Decide**: present to the user. Approve, request changes, or reject before any code is written.
4. **Implement**: implementer works from the proposal; tracks multi-file progress via TaskCreate / TaskUpdate.
5. **Verify**: reviewer checks code quality AND plan adherence (completeness, coherence, scope discipline).
6. **Test**: tester works from the implementer's change summary and the reviewer's risk areas.

Steps 1–3 prevent building the wrong thing. Steps 5–6 catch both code defects and plan deviations.

## Context Compaction Guidance

When summarizing the conversation for compaction, preserve:

- Current task state.
- Modified files.
- Architecture decisions.
- Code style requirements.
- Unresolved issues.

After compaction, re-read project CLAUDE.md files before continuing work.
