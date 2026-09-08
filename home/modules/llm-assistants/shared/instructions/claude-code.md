## Claude Code

### Prose Polish

Before writing to the file, a hook rewrites your Markdown prose, question text, and certain MCP fields to enforce the guidance above. Treat this output as final rather than reverting or re-editing it toward your original wording, checking only to restore any substantive claim or qualification that was dropped.

### Bash Tool Usage

**Never prefix Bash commands with shell comments.** The `command` field must start with the actual command, since leading comments break permission pattern matching. Use the Bash tool's `description` parameter for explanations instead.

### Web Search

`WebSearch` runs on Anthropic's own infrastructure rather than locally, so it fails under any `corp-gateway-*` profile, where `ANTHROPIC_BASE_URL` points at the corp Bifrost gateway. On those profiles go straight to Exa (`mcp__Exa__web_search_exa`) instead of spending a turn on a call that cannot succeed. `WebFetch` is a local tool and works on every profile.

### Additional MCP Servers

The shared MCP servers are documented in the shared instructions above. Claude Code adds these:

- **Context7** (`mcp__plugin_context7-plugin_context7__*`): library and framework documentation lookups, provided by the context7 plugin when online. Always resolve the library ID first, then query the docs with a specific question.
- **IDE** (`mcp__ide__*`): `getDiagnostics` for language server errors / warnings, `executeCode` for running Python in Jupyter kernels when working with notebooks.

#### Codex (`mcp__Codex__*`)

Delegate bounded, multi-step work or independent review when a separate context helps. Prefer direct execution for quick commands or work that depends heavily on the current conversation. Check the integration's actual tools and permissions before assigning work.

### Agent Execution

Use subagents for independent tasks and Agent Teams when peers need shared task state or direct messaging. The `codex-worker` role delegates through the Codex MCP integration and has a restricted tool set. Isolate parallel writers with `Agent({ isolation: "worktree" })`.

### Context Compaction Guidance

When summarizing for compaction, preserve current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, re-read the project's AGENTS.md before continuing.
