## Git Workflow

- Verify the current branch before committing. If a new branch was created, switch to it before making commits.
- When preparing PRs, verify that the diff and commit count match expectations before pushing.

## Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, not a `# comment`. Use the Bash tool's `description` parameter for explanations instead. Shell comments in the command string break permission pattern matching.

## MCP Server Usage

Prefer MCP tools over equivalent Bash commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Codex (`mcp__Codex__*`)

Use for delegating self-contained, multi-step coding tasks to an autonomous agent powered by GPT-5.4. Codex runs with full shell access and its own MCP servers, making it useful for independent exploration, code generation, and command execution in a separate context window.

Use Codex when:

- A task requires autonomous multi-step work with shell commands.
- Offloading work to a separate context window is useful.
- An independent second opinion or alternative implementation path is valuable.

Do not use Codex when:

- Claude Code can handle the work directly with less overhead.
- The task depends heavily on the current conversation context.
- The work is just a quick one-shot command.

### DeepWiki (`mcp__DeepWiki__*`)

Use when exploring or asking questions about GitHub repositories.

### Fetcher (`mcp__Fetcher__*`)

Fallback web fetcher using Playwright. Use only when the native web fetch path fails with blocking errors such as 403 responses or bot protection.

### Filesystem (`mcp__Filesystem__*`)

Available for file operations with built-in directory sandboxing. Use when the native Read / Write / Edit tools are insufficient or when you need operations such as `move_file`, `directory_tree`, or `search_files`.

### Git (`mcp__Git__*`)

Prefer MCP Git tools for git operations. They accept a `repo_path` parameter, keeping the working directory unchanged and avoiding `git -C` patterns that bypass Bash permission matching.

### GitHub (`mcp__GitHub__*`)

Use for all GitHub API interactions. Prefer over `gh` CLI commands because MCP provides structured responses and pagination.

### GitLab (`mcp__GitLab__*`)

Use for all GitLab API interactions. Prefer over `glab` CLI commands because MCP provides structured responses. For repository exploration on GitLab, use `glab_repo_view` and `glab_api` (analogous to DeepWiki for GitHub).

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

- **Sequential pipeline**: researcher → architect → implementer → reviewer → tester.
- **Parallel exploration**: Launch multiple researchers across different areas.
- **Review gate**: Run reviewer after significant implementation changes.
- **Codex offloading**: Use codex-worker for orthogonal tasks that benefit from a separate context window.
- **Exploration gate**: researcher(s) → architect (proposal mode) → user decision → implementer → reviewer → tester. Use when the approach is unclear and premature implementation would waste effort.
- **Bug investigation**: Spawn one or more debuggers with distinct hypotheses.

### Feature Development Workflow

For non-trivial features, follow the structured pipeline to prevent wasted implementation effort:

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
