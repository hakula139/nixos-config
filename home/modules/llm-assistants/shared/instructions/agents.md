## MCP Server Usage

Prefer MCP tools over equivalent shell commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Atlassian

Scoped to Confluence. Use for searching, reading, and navigating Confluence pages, spaces, and page hierarchies. Read operations are auto-approved. Write operations (create / update / delete pages, add comments / labels, upload attachments) require user confirmation.

### Brave Search

Fallback web search. Use only when the native web search fails, returns unhelpful results, or when a specialized search type is needed (news, images, video, local businesses). Supports summarization of search results. Do not use as the primary search path — prefer native web search by default.

### Context7

Library and framework documentation lookups. Always resolve the library ID first, then query the docs with a specific question.

### DeepWiki

AI-powered documentation for public GitHub repositories. Use for understanding unfamiliar repos — architecture, patterns, API design. Query specific questions or browse the generated wiki structure.

### Fetcher

Browser-based web fetcher using Playwright. Fallback for when native web fetch is blocked (403 responses, bot protection) or the page requires JavaScript rendering. Supports content extraction and multi-URL fetching.

### Filesystem

Structured file operations with directory sandboxing. Use for operations beyond native file tools: moving files, directory trees, reading multiple files at once, glob-based search. Sandboxed to allowed directories.

### Git

Structured git operations. Prefer over shell `git` commands — they accept a `repo_path` parameter, keeping the working directory unchanged and avoiding permission pattern issues.

### GitHub

GitHub API — issues, PRs, code search, reviews, releases, repository management. Prefer over `gh` CLI for structured responses and pagination.

### GitLab

GitLab API — issues, merge requests, pipelines, labels, repository management. Prefer over `glab` CLI. Use `project_id` as the URL-encoded project path (e.g., `group/subgroup/project`).

## Custom Agent Roles

Custom agent roles are available in addition to built-in agents. Use the most specific role that matches the task:

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
