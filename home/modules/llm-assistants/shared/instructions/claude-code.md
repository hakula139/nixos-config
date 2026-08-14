## Session Patterns

Treat Claude Code as a capable engineer you delegate to. Avoid line-by-line steering.

- **Specify the task up front.** State intent, constraints, acceptance criteria, and relevant file locations in the first turn. Well-scoped first turns spend fewer tokens than progressively clarifying across many.
- **Batch questions.** Every user turn adds reasoning overhead. Collect clarifications and ask together.
- **Trust adaptive thinking.** The model decides per step whether to think. Skip scaffolding like `"think hard"` or `"summarize every N tool calls"`. When specific steering helps, state it positively (e.g., `"This problem is harder than it looks; think step by step"`).
- **Literal instruction following.** State scope explicitly (`"Apply to every section in the file"` rather than `"Apply this"`). Ambiguity gets scoped narrowly.

## Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, since leading comments break permission pattern matching. Use the Bash tool's `description` parameter for explanations instead.

## Web Search

`WebSearch` runs on Anthropic's own infrastructure rather than locally, so it fails under any `corp-gateway-*` profile, where `ANTHROPIC_BASE_URL` points at the corp Bifrost gateway. On those profiles go straight to Brave Search (`mcp__BraveSearch__brave_web_search`) instead of spending a turn on a call that cannot succeed. Check the statusline for the active profile when unsure. `WebFetch` is a local tool and works on every profile.

## MCP Server Usage

The shared MCP servers are documented in the shared instructions above. Claude Code adds these:

- **Context7** (`mcp__plugin_context7-plugin_context7__*`): library and framework documentation lookups, provided by the context7 plugin when online. Always resolve the library ID first, then query the docs with a specific question.
- **IDE** (`mcp__ide__*`): `getDiagnostics` for language server errors / warnings, `executeCode` for running Python in Jupyter kernels when working with notebooks.

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

## Agent Team Workflow

Agents run in two modes:

- **Subagents**: focused workers that report only to the orchestrator. Use when agents do not need to talk to each other.
- **Agent Teams**: peer-to-peer coordination via shared task state and `SendMessage`. Use when agents need to share findings, challenge conclusions, or hand work off directly.

All agents inherit the parent tool set. Behavioral boundaries live in each agent's prompt. The exception is **codex-worker**, which keeps a narrower tool set so it actually delegates to Codex instead of doing the work itself.

The available agents and their descriptions are surfaced automatically by the harness. Pick the most specific role for the task.

### When to Use Agents

Subagents spawn conservatively by default. When parallel work genuinely helps, ask explicitly and describe the fan-out (e.g., `"launch parallel researchers across these three directories"`).

Use agents for parallelism across independent items, a specialist perspective, or to offload from a crowded context window. Skip them when the work fits in a single response, needs continuous user interaction, or the delegation overhead exceeds the benefit. Isolate parallel writers with `Agent({ isolation: "worktree", ... })`.

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

When summarizing for compaction, preserve current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, re-read the project's AGENTS.md before continuing.
