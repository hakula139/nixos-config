## Claude Code

- **Prose polish**: a hook rewrites your Markdown prose, question text, and certain MCP fields before writing them. Treat its output as final, restoring only substantive claims or qualifications it dropped.
- **Bash**: never start the `command` field with a shell comment because that breaks permission pattern matching. Put explanations in the `description` parameter.
- **Web search**: native `WebSearch` works when the selected profile enables it. Otherwise, use Exa MCP when it is available. `WebFetch` runs locally and works either way.
- **IDE MCP** (`mcp__ide__*`): use `getDiagnostics` to check for language server errors and warnings. Use `executeCode` to run Python in Jupyter kernels when working with notebooks.
- **Agents**: use subagents for independent tasks and Agent Teams when peers need shared task state or direct messaging. Isolate parallel writers with `Agent({ isolation: "worktree" })`.
- **Compaction**: preserve the current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, reread the project's AGENTS.md before continuing.
