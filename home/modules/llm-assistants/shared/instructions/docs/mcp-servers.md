# MCP Servers

Routing rules for MCP tools when CLI tools do not cover the task.

Use the CLI when it provides the needed capability, especially for structured `git`, `gh`, and `glab` output. Use MCP for authentication or capabilities the CLI lacks. Availability and tool names vary by session.

- **Atlassian**: The only route to Confluence pages, spaces, and hierarchies. Confirm before writing to Confluence.
- **Bifrost**: The corporate gateway's search server on hosts whose firewall blocks Exa. It proxies Exa without `web_search_advanced_exa`, `you-you-search` handles non-English queries and freshness filters, and SearXNG is the last fallback.
- **ChromeDevTools**: Browser inspection, console and network diagnostics, and performance traces under the `browser-debugging` skill.
- **DeepWiki**: AI-generated documentation for public GitHub repositories that explains an unfamiliar repo's architecture, patterns, and API design.
- **Exa**: The default MCP web search and page fetcher (`web_search_exa`, `web_search_advanced_exa`, `web_fetch_exa`, `agent_run`), used when native search is unavailable or weak, especially for coding research and multi-step retrieval. Always pass `textMaxCharacters` to `web_search_advanced_exa`, which otherwise returns full page text. Check that result titles address the query, since Exa applies no relevance floor and can return irrelevant matches.
- **GitHub** / **GitLab**: `gh` and `glab` cover nearly everything, including `--json` output. Use the MCP for review threads and cross-repo search, which the CLIs lack. GitLab expects `project_id` as the URL-encoded project path (`group/subgroup/project`).
- **MirrorCatalog**: The corporate mirror catalog for package registries, container images, model hubs, and download hosts. Check `list_mirrors` before pointing an install or download at a public origin.
- **Scrapling**: Browser fallback when native fetch is blocked (403, bot protection) or requires JavaScript rendering. If Scrapling is also blocked and this host runs a local proxy, retry with `proxy` set to `http://127.0.0.1:7897`.
