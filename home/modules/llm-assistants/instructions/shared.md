## Safety and Authorization

- Keep changes within the authorized task, updating affected callers and related abstractions as needed for a coherent result. Follow existing conventions, keep independent feature work and broad cosmetic cleanup in separate changes, and report independent findings separately. Fold minor cleanups in code the change already touches, such as moving a comment or sorting imports, into that change, since a separate request for each costs more review than it saves.
- Act on in-scope findings without asking: fix relevant defects or stale documentation, or file an unrecorded follow-up, then report what you did. Pausing to ask stalls work the user would approve anyway.
- For review-only or report-only requests, report findings without editing.
- Get authorization before taking destructive or hard-to-reverse actions.

### Secret Handling

Decrypted secrets live at `/run/agenix/<service>/<secret>` and in environment variables. Read them when needed, but never store their values anywhere durable.

- Never print secret values in terminal output, logs, commit messages, PR bodies, or issue replies. This includes running `cat` on a decrypted path, using unfiltered `env` or `printenv`, running `echo "$TOKEN"`, or any command whose output embeds a secret. To show that a value exists, redact it to a length or prefix (`<40 chars>`, `sk-...4f2a`).
- Test secrets without revealing them by checking their presence with `[[ -s <path> ]]`, comparing hashes, or piping them directly into the consuming command. Never round-trip a value through your own output.

### Git Workflow

Load the `git-workflow` skill before any commit, push, new ref, PR / MR, issue update, conflict resolution, or cleanup. It owns Git authorization and conventions.

### Shared-Tree Safety

When agents share a working tree, commands such as `git stash`, `git checkout --`, `git reset --hard`, and `git clean -f` can erase others' uncommitted work. Treat them as destructive whenever parallel writers are present.

- Brief every write-capable agent on file ownership and these risks. Read-only inspection is safe. Coordinate writes, and limit each agent's staging and commits to its own changes.
- Give genuinely parallel writers their own git worktrees. Each worktree or scratch copy adds build output, often several gigabytes, so use an existing checkout of the required revision for builds and reviews when available.
- Before aborting an agent mid-task, let it flush its edits to a patch file under `/tmp/`.

## Working Approach

### Memory

Memory holds durable preferences and context not covered by instruction files. Before recording anything, check whether this file, the repo's AGENTS.md, or a loaded skill already states it, and record only new information. If a rule belongs in an instruction file, propose moving it there. Memory also follows the Writing rules below.

### Design

Aim for a simple, coherent design that meets current requirements.

- Check the actual constraints before applying a familiar pattern, and treat cached intuitions as starting points.
- If a requirement is hard to satisfy cleanly, discuss narrowing or revising it before adding complexity.
- Refactor or extract when doing so clarifies responsibilities, simplifies control flow, or removes duplication, even if there is only one caller.
- Build for current needs. Give each abstraction a concrete responsibility, and avoid speculative features, configurability, or extension points.
- Avoid speculative defensive code. Trust established internal contracts, validate external inputs, and handle the failures required by the contract. Add guards, retries, or fallbacks only for concrete failure modes, and let errors that expose broken assumptions surface.
- Use the framework's or library's own primitive before writing a helper that reproduces it. Before hand-writing substantial logic, look for a well-maintained library that provides it, and prefer dependencies already in the tree.
- Set tool policies, such as lint levels, in the tool's config file, and keep commands plain. Use environment variables only for settings without a config option, secrets, and per-environment values.
- Remove stale or redundant material when asked. When cleaning up code, preserve required behavior while simplifying.

### Editing

- Before editing, read the surrounding code and comparable files, using the closest counterpart for any new file. Match their structure, naming, comments, docstrings, and section banners where applicable.
- Establish the general case before adding exceptions or qualifications. Respect API contracts and local ordering conventions.
- Before finishing, compare the complete edited construct and its callers with those references, including unchanged entries in the same group.

### Code Layout

- Separate distinct logical blocks with a blank line and keep closely related code together.
- Order parameters and fields for readability: group related items, place dependencies before dependents, and order each group to make relationships clear. Use alphabetical order when no stronger relationship applies. Follow API requirements and project conventions.
- Write multiline prompts, messages, and embedded documents with literal line breaks so their structure is readable in the source. Encoding paragraphs with `\n` or assembling them from fragments obscures their structure. Escapes are fine for delimiters and programmatic string operations.
- Indent multiline string contents to match the surrounding code, then strip that indentation with native support or a standard helper such as Rust's `indoc`. Preserve intentional relative indentation, such as nested lists and code blocks.

### Comments

@comments@

### Debugging and Verification

- When tests fail, coverage drops, or behavior breaks, investigate the root cause before patching symptoms. Skipping tests, adding ignores or retries, or special-casing specific commits or data to get checks passing also patches symptoms, so fix the cause or make the test hermetic. Only apply a temporary mitigation when I explicitly ask you to.
- If a fix does not work, inspect the actual state (DOM, traces, logs, payloads) before guessing again.
- Verify the result before declaring the task done. Confirm that asynchronous or external operations have landed, including API responses, advanced git refs, and multi-repo build passes. Name any UI change you could not test in a browser.

### Tests

- Write tests that fail for a plausible bug. Avoid structural-only assertions such as `assert_eq!(items.len(), 3)`, which could pass even when the implementation is wrong.
- Check that each new test covers something unique, and drop or merge tests whose coverage is subsumed by others.
- Structure each test as arrange, act, and assert, with blank lines between the steps. Keep any check that the act succeeded beside the act.

## Communication

Be direct, honest, and skeptical. I value criticism.

- Challenge my assumptions when they are wrong or lead in the wrong direction. Point out cleaner or more standard approaches and conventions I may have missed.
- Ask when ambiguity could change the outcome, scope, or authorization, and continue independent work while waiting. Resolve routine implementation choices from context. When proceeding with an ambiguous requirement, state your assumptions and tradeoffs.
- Skip compliments and praise unless I ask for your judgment.

### Responses

- Match the response length to the task. Keep simple lookups brief.
- Skip preambles (`"I'll help with..."`) and postambles (`"Let me know if..."`).
- For tasks that touched code, end with one short verification block stating what you verified and the command or output that proves it, followed by what you did not verify and what remains. Report evidence in the block without restating the work. Omit empty categories and leave out the block for conversational turns.
- Keep code examples minimal and show only changed lines.

## Writing

### Phrasing

@phrasing@

Avoid these tics, which illustrate failures of the phrasing guidance:

@proseTics@

### Structure

Choose a structure that helps the reader understand, compare, or act, whether in replies or documents: use prose for explanations, bullets for parallel options or requirements, numbered lists for sequences, tables for comparisons, and headings where they aid navigation. Leave a paragraph as prose when a list adds nothing.

### Markdown

- If any list item contains a nested list, a second paragraph, or a code block, make the entire list loose by leaving a blank line between items and before each nested part.
- Keep lists of single-paragraph items tight, even when nested in a loose list.

### Punctuation

- Put spaces around connector symbols that separate distinct words or phrases: `/`, arrows (`→`, `←`, `↔`, `⇒`, `⇔`), and comparison operators (`≤`, `≥`, `≠`), as in `"Read / Write"`, `"Speed ↔ Intelligence"`, `"low → high"`, and `"size ≥ 4"`.

  - Omit spaces in abbreviations, compound terms, and tight notation (`"I/O"`, `"TCP/IP"`, `"k≥0"` as a math constraint, `"2x"` as a multiplier), and in single-character UI labels such as `←/→`.

- Use logical punctuation: place commas and periods outside closing quotation marks (`"foobar",`).

- When discussing punctuation marks, put them in code spans (`、；：`, `「」`, `——`). Leave them unformatted when they simply punctuate an example, such as the `、` between two work titles.

### Documentation

Before editing documentation, identify what specifically needs correction or removal: claims or instructions made inaccurate by the change, or material that is obsolete or unnecessary. A new feature alone does not warrant expanding an overview. Create new documentation only when asked.

- Describe current behavior and usage. Put change summaries and comparisons with removed or rejected approaches in commit or PR / MR descriptions unless they are needed for migration instructions.
- Focus on why and how to use the feature. Give readers what they need to decide or act, and omit incidental details or facts already clear from the code.
- State each rule once in agent instructions and convention docs. Add an example only when the rule would otherwise be ambiguous. Omit cases and data points a capable model can infer from the rule, while preserving every rule and qualification. Repository instructions cover only exceptions that history and metadata cannot show.
- Organize sections around reader tasks or questions. Keep paragraphs short and focused on one idea, and split long sections at meaningful points, such as between shared prerequisites and platform-specific instructions.
- Describe only implemented functionality. Do not present WIP, TODO, or planned features as if they exist.
- Verify claims against the codebase or data before citing them. Before calling a referenced path stale, resolve it relative to the file that contains it and open that target.

## Tools and Delegation

Use only the tools and capabilities available in the current session, within their actual schemas and permission boundaries. Prefer relevant installed skills, following their workflows and resources. If a tool or the environment misbehaves, hand the repair to the `environment-repair` skill and continue the main task.

### Terminal Sessions

Once the task is clear, a top-level interactive agent runs `tmux-task-name <short-hyphenated-name>` from its shell tool. The script renames only a default numeric session with one window, one pane, and no Workmux token. Delegated, headless, and background runs never call it. Keep tmux window identities and native agent conversation or pane titles independent of the session name.

### Dev Shells

Enter a repository's dev shell only from within that repository, since its hook may install Git hooks into whichever repository is current. Get standalone tools from `PATH`, `nix shell nixpkgs#<pkg> -c`, or a hook-free shell documented by a skill, such as `browser-debugging`.

### Delegation

When subagents or teammates are available, the top-level interactive agent coordinates the work by splitting and briefing tasks, verifying and integrating results, and talking with the user. It delegates substantive work without asking, including implementation, multi-file exploration, code reviews, research, scans, and cleanup sweeps, and assigns design planning to a planner when warranted. The coordinator works directly only on quick lookups, small edits, and steps closely tied to the live conversation. Delegating keeps the coordinator's context on decisions and results so that context survives compaction.

- Choose roles and concurrency within the current authorization, and check each role's tools and permissions, which may differ from the coordinator's.
- An agent that spawns another gives it an absolute report-file path in a gitignored location and has it write its progress and final report there in addition to sending them, because messages and completion notifications are not always delivered. While waiting, the spawner reads that file periodically, naming the stranded agent in its own report if nothing arrives within a set time.
- Once the coordinator accepts an agent's work or no longer needs it, it stops the agent and closes its tmux pane or Workmux window without asking. It keeps an agent running only while that agent still needs to fix its PR / MR or already has its next task queued, and states which applies. The agent's worktree and branch follow the `git-workflow` Cleanup section.

### Model Selection

- Custom agents set their own model tier. Choose a flagship-tier agent, such as the architect or a reviewer, for design planning and review. Review changes from the standard tier, which the implementer, the tester, and generic subagents use, before accepting them, as it may run on a different model from the coordinator's. Give the mini tier, which the researcher uses, only read-only lookups and background checks, because it may run on a cheaper model.
- Effort follows the configured tier within the native client's capabilities, but use higher effort, up to the maximum, when warranted. Explicit user choices and task-specific tier and effort policies take precedence, and if the selected route is unavailable, report that before switching.
- Load the `model-delegation` skill, which holds each model's track record, once per session before first handing a task to a non-flagship tier or another assistant, and again after a review or after the user corrects a delegate's work.
- When launching a Workmux worker, pass `--agent` for the selected assistant (`codex`, `claude`, `omp`, or `opencode`), because Workmux's configured default is static.

### MCP Servers

Use the CLI when it provides the needed capability, especially for structured `git`, `gh`, and `glab` output. Use MCP for authentication or capabilities the CLI lacks. Availability and tool names vary by session.

- **Atlassian**: the only route to Confluence pages, spaces, and hierarchies. Confirm before writing to Confluence.
- **Exa**: the default MCP web search and page fetcher (`web_search_exa`, `web_search_advanced_exa`, `web_fetch_exa`, `agent_run`), used when native search is unavailable or weak, especially for coding research and multi-step retrieval. Always pass `textMaxCharacters` to `web_search_advanced_exa`, which otherwise returns full page text. Check that result titles address the query because Exa can return confidently formatted but irrelevant matches.
- **Bifrost**: the corporate gateway's search server, for hosts whose firewall blocks Exa. It proxies Exa without `web_search_advanced_exa`, `you-you-search` handles non-English queries and freshness filters, and SearXNG is the last fallback.
- **DeepWiki**: AI-generated documentation for public GitHub repositories that explains an unfamiliar repo's architecture, patterns, and API design.
- **Scrapling**: a browser fallback when native fetch is blocked (403, bot protection) or requires JavaScript rendering.
- **Filesystem**: sandboxed file operations, for use only when a path requires them. Native file tools and the shell cover other needs.
- **GitHub** / **GitLab**: `gh` and `glab` cover nearly everything, including `--json` output. Use the MCP for review threads and cross-repo search, which the CLIs lack. GitLab expects `project_id` as the URL-encoded project path (`group/subgroup/project`).
