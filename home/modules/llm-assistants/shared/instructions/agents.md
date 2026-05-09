## Git Workflow

- **Wait for explicit per-PR approval before merging.** Earlier blanket approvals do not extend to PRs opened later in the session. After opening a PR, push, report the URL, and wait for `lgtm` or `merge` referencing that specific PR.
- **PR body authoring.** Prefer `gh pr edit --body-file <file>` or `gh pr create --body-file -` over inline `--body "$(cat <<'EOF' ... EOF)"`. The file-input form avoids shell-escape bugs around backticks and `$()` substitution. Either way, do not reference prior PRs as `#N` in the body. GitHub auto-expands them into title cards that break sentence flow.

## MCP Server Usage

Prefer MCP tools over equivalent shell commands or web searches. MCPs provide structured interfaces, better error handling, and work within the configured permission model.

### Atlassian

Scoped to Confluence. Search, read, and navigate pages, spaces, and hierarchies. Read operations auto-approved; writes require user confirmation.

### Brave Search

Fallback web search. Use when native web search fails, returns unhelpful results, or when a specialized search type is needed (news, images, video, local businesses). Supports result summarization.

### Context7

Library and framework documentation lookups. Always resolve the library ID first, then query the docs with a specific question.

### DeepWiki

AI-powered documentation for public GitHub repositories. Use for unfamiliar repos: architecture, patterns, API design.

### Fetcher

Browser-based web fetcher using Playwright. Fallback for when native web fetch is blocked (403 responses, bot protection) or the page requires JavaScript rendering. Supports content extraction and multi-URL fetching.

### Filesystem

Structured file operations with directory sandboxing. Use for operations beyond native file tools: moving files, directory trees, reading multiple files at once, glob-based search. Sandboxed to allowed directories.

### Git

Structured git operations. Prefer over shell `git` commands, since they accept a `repo_path` parameter, keeping the working directory unchanged and avoiding permission pattern issues.

### GitHub

GitHub API for issues, PRs, code search, reviews, releases, and repository management. Prefer over `gh` CLI for structured responses and pagination.

### GitLab

GitLab API for issues, merge requests, pipelines, labels, and repository management. Prefer over `glab` CLI. Use `project_id` as the URL-encoded project path (e.g., `group/subgroup/project`).

## Custom Agent Roles

Custom roles supplement built-in agents. Use the most specific role for the task:

- **architect** for design and structure review.
- **debugger** for root-cause analysis.
- **implementer** for writing or refactoring code.
- **researcher** for fast context gathering.
- **reviewer** for code review and bug finding.
- **tester** for tests and test failures.
- **usability-reviewer** for user-facing clarity and ergonomics.

Spawn agents when parallelism or a narrower perspective helps. Skip them for trivial single-step work.

## Skills

Prefer installed skills that match the task. Reuse their workflow, scripts, and templates instead of rebuilding ad hoc.
