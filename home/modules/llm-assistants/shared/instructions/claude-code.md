## Claude Code

### Prose Polish

Before writing to the file, a hook rewrites your Markdown prose, question text, and certain MCP fields to enforce the guidance above. Treat this output as final rather than reverting or re-editing it toward your original wording, checking only to restore any substantive claim or qualification that was dropped.

### Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, since leading comments break permission pattern matching. Use the Bash tool's `description` parameter for explanations instead.

### Web Search

Native `WebSearch` is available when the selected profile enables it. Otherwise, use Exa MCP when it is available. `WebFetch` runs locally and works independently of native search support.

### Additional MCP Servers

The shared MCP servers are documented in the shared instructions above. Claude Code adds these:

- **Context7** (`mcp__plugin_context7-plugin_context7__*`): library and framework documentation lookups, provided by the context7 plugin when online. Always resolve the library ID first, then query the docs with a specific question.
- **IDE** (`mcp__ide__*`): `getDiagnostics` for language server errors / warnings, `executeCode` for running Python in Jupyter kernels when working with notebooks.

### Agent Execution

Use subagents for independent tasks and Agent Teams when peers need shared task state or direct messaging. The `codex-worker` role delegates bounded work through `acpx` using the shared `acp-delegate` skill, then verifies Codex's output. Isolate parallel writers with `Agent({ isolation: "worktree" })`.

### Context Compaction Guidance

When summarizing for compaction, preserve current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, re-read the project's AGENTS.md before continuing.
