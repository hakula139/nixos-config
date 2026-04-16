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

Custom agents are available for delegation when tasks benefit from specialization or parallelism. Agents support two modes: **subagents** and **Agent Teams**.

### Available Agents

All agents inherit the full tool set from the parent session. Behavioral boundaries are enforced by each agent's prompt, not hard tool restrictions, except for **codex-worker**, which keeps a narrower tool set so it actually delegates to Codex rather than doing the work itself.

- **architect**: Architecture review, design critique, and pattern analysis.
- **codex-worker**: Delegates self-contained tasks to Codex MCP for independent parallel work.
- **implementer**: Code writing, feature implementation, and refactoring.
- **researcher**: Codebase exploration and documentation lookup.
- **reviewer**: Code quality, security, and bug detection.
- **debugger**: Hypothesis-driven debugging and root cause analysis.
- **tester**: Test writing and execution, and failure analysis.
- **usability-reviewer**: Usability and clarity review for user-facing surfaces.

### Subagents vs Agent Teams

**Subagents** are focused workers that report only to the orchestrator. Use them when agents do not need to communicate with each other.

**Agent Teams** provide peer-to-peer coordination via shared task state and direct messages. Use them when agents need to share findings, challenge conclusions, or hand work off directly.

### When to Use Agents

Use agents when:

- A task benefits from parallel work.
- The task is self-contained.
- A focused specialist perspective is useful.
- The main conversation context is getting large.

Do not use agents when:

- The task is simple and direct.
- The task requires continuous user interaction.
- Delegation overhead outweighs the benefit.

### Coordination Patterns

Each pattern specifies its mode: **Subagents** (independent, report back) or **Agent Team** (peer communication via `SendMessage`).

- **Sequential pipeline** (Subagents): researcher → architect → implementer → reviewer → tester. Each agent's output feeds the next. See Feature Development Workflow below for the detailed step-by-step with a user approval gate.
- **Feature dev** (Agent Team): Full delivery pipeline with direct peer coordination. Members: 1 researcher, 1 architect, 1-2 implementers, 1 reviewer, 1 tester. Task dependencies enforce ordering. Implementers use worktree isolation when modifying different areas in parallel.
- **Parallel review** (Subagents): 3 reviewers with distinct lenses (security, correctness, test coverage). Each reports independently; the orchestrator synthesizes.
- **Parallel exploration** (Subagents) / **Research swarm** (Agent Team): Multiple researchers across different areas. As subagents, each reports independently. As a team, researchers share discoveries and redirect each other's investigation.
- **Bug investigation** (Subagents) / **Investigation** (Agent Team): Debuggers with competing hypotheses. As subagents, each reports independently. As a team, teammates actively challenge each other's theories via direct messages.
- **Review gate** (Subagent): Run reviewer after significant implementation changes.
- **Codex offloading** (Subagent): codex-worker for orthogonal tasks in a separate context window.

### Feature Development Workflow

Detailed step-by-step for the sequential pipeline. For non-trivial features, follow this to prevent wasted implementation effort:

1. **Explore** (optional): Use researcher(s) to investigate the problem space, gather context on existing patterns, and evaluate options. Skip for well-understood changes.
2. **Propose**: Use architect in "Design Proposal" mode to produce a structured plan with motivation, scope, approach, impact, and risks.
3. **Decide**: Present the proposal to the user. Approve, request changes, or reject before any code is written.
4. **Implement**: Use implementer with the architect's proposal as input. For multi-file work, the implementer tracks progress via TaskCreate / TaskUpdate.
5. **Verify**: Use reviewer with both the architect's proposal and implementer's changes. The reviewer checks code quality AND plan adherence (completeness, coherence, scope discipline).
6. **Test**: Use tester with the implementer's change summary and reviewer's risk areas.

Steps 1-3 prevent building the wrong thing. Steps 5-6 catch both code defects and plan deviations. Each agent's output is shaped by pipeline contracts that define what it expects from upstream and produces for downstream.

## Context Compaction Guidance

When summarizing the conversation for compaction, preserve:

- Current task state.
- Modified files.
- Architecture decisions.
- Code style requirements.
- Unresolved issues.

After compaction, re-read project CLAUDE.md files before continuing work.
