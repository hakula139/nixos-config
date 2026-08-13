## MCP Server Usage

The shared MCP servers are documented in the shared instructions above. These tool-specific servers may also be available:

- **Context7** (Codex): library and framework documentation lookups. Always resolve the library ID first, then query the docs with a specific question.
- **Codex** (OpenCode): delegates self-contained, multi-step coding tasks to the Codex agent, which runs with full shell access and its own MCP servers in a separate context window. Use for autonomous multi-step work or an independent second opinion. Skip it for quick one-shot commands or work that depends heavily on the current conversation context.

## Custom Agent Roles

Custom roles supplement built-in agents. Each registered agent carries its own description. Pick the most specific role for the task, and spawn agents when parallelism or a narrower perspective helps. Skip them for trivial single-step work.

## Skills

Prefer installed skills that match the task. Reuse their workflow, scripts, and templates instead of rebuilding ad hoc.
