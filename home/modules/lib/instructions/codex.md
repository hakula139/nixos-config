## MCP Server Usage

Prefer MCP tools over equivalent shell commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Context7

Use for library and framework documentation lookups. Always resolve the library ID first, then query the docs with a specific question.

### DeepWiki

Use when exploring or asking questions about GitHub repositories.

### Fetcher

Use as a fallback web fetcher when the normal web path is blocked or when a page requires a real browser context.

### Filesystem

Use for file operations that are better expressed through structured tools than raw shell commands, such as moving files, reading multiple files, or searching with glob patterns.

### Git

Prefer MCP Git tools when operating on repositories, especially outside the current working directory. They keep repository targeting explicit via `repo_path`.

### GitHub

Use for GitHub API operations such as issues, pull requests, searches, reviews, and repository management.

## Web and Search

Use the native web search capability for current public-web information. Use Fetcher when you need direct page retrieval or when normal web access is blocked.

## Custom Agent Roles

This Codex profile exposes custom agent roles in addition to the built-in worker types. Use the most specific role that matches the task:

- **architect** for design and structure review.
- **debugger** for root-cause analysis.
- **implementer** for writing or refactoring code.
- **researcher** for fast context gathering.
- **reviewer** for code review and bug finding.
- **tester** for tests and test failures.
- **usability-reviewer** for user-facing clarity and ergonomics.

Use these roles when parallelism or a narrower perspective helps. Do not spawn agents for trivial single-step work.

## Skills

Prefer installed skills when a task clearly matches one. Reuse the skill workflow, scripts, and templates instead of rebuilding the same process ad hoc.
