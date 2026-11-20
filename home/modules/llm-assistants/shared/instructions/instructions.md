## Read before you act

Before your first edit or command in any installed or repository-local skill's area, load every matching skill if it is not already in context. Read the linked guide before starting work in its area, applying devkit's guides by default while preserving justified repository-specific requirements:

| When the task involves                                                | Read                                     |
| --------------------------------------------------------------------- | ---------------------------------------- |
| Designing or planning software, refactoring, or cleaning up code      | [Code Design]                            |
| Editing source files, formatting, or writing comments and docstrings  | [Editing and Comments] and `code-layout` |
| Debugging failures, verifying behavior, or writing and running tests  | [Verification and Tests]                 |
| Writing or polishing prose, plans, memory, or commit / PR / MR bodies | [Writing]                                |
| Authoring, updating, or reviewing repository documentation or rules   | [Documentation] and [Writing]            |
| Delegating to subagents or teammates, or selecting models and effort  | [Delegation]                             |
| Managing tmux sessions, Workmux workers, or interactive panes         | [Terminals and Workmux]                  |
| Searching the web, fetching pages, or calling MCP servers             | [MCP Servers]                            |
| Commits, pushes, branches, worktrees, PRs / MRs, issues, or cleanup   | `git-workflow` skill                     |
| Repository settings, rulesets, or labels                              | [GitHub settings]                        |
| Preparing or publishing a release                                     | `release` skill and [Releasing]          |

## Safety

- Keep changes within the authorized task, updating affected callers and related abstractions for a coherent result. Follow existing conventions, keep independent feature work and broad cosmetic cleanup in separate changes, and fold minor cleanups in touched code into the same change.
- Act on in-scope defects or stale documentation without asking and report what you did. On review-only or report-only requests, report findings without editing.
- Get authorization before taking destructive, hard-to-reverse, or unapproved external actions.

### Secret Handling

Secrets live at `/run/agenix/<service>/<secret>`, in environment variables, and in credential files such as `.env`. Use them by path or pipe when needed, and never store their values anywhere durable.

- Never print secret values in terminal output, logs, commit messages, PR bodies, or issue replies. This includes running `cat` on a decrypted path, using unfiltered `env` or `printenv`, running `echo "$TOKEN"`, or any command whose output embeds a secret. Redact proof of presence to a length or prefix (`<40 chars>`, `sk-...4f2a`), and name only keys (with at most a length) in reports, handoffs, and messages to other agents.
- Test secrets without revealing them by checking presence with `[[ -s <path> ]]`, comparing hashes, or piping them directly into the consuming command. Never round-trip a value through your own output.
- Write a value only into its agenix secret or the untracked file that consumes it, and pass it to commands by path or variable.

### Shared-Tree Safety

- When parallel writers share a working tree, treat `git stash`, `git checkout --`, `git reset --hard`, and `git clean -f` as destructive.
- `git commit` takes the whole index, including files another session staged, so check `git diff --cached --name-only` right before committing and `git show --stat HEAD` after.
- Create worktrees with Workmux (`git-workflow`) and never an assistant's built-in worktree feature (`--worktree`, `/worktree`, `create_worktree`, `/wt`, or `omp worktree add`).

## Environment and Shell

The configuration repository is nixos-config (`${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/repository`), whose `AGENTS.md` locates the sources. If a tool or the environment misbehaves, hand the repair to `harness-repair` and continue the main task.

- **Terminal sessions**: Once the task is clear, a top-level interactive agent runs `tmux-task-name <short-hyphenated-name>` (delegated, headless, and background runs skip it). See [Terminals and Workmux] for session layout, Workmux workers, and interactive panes.
- **Dev shells**: Enter a repository's dev shell only from within that repository so its hook does not install Git hooks elsewhere. Get standalone tools from `PATH`, `nix shell nixpkgs#<pkg> -c`, or `nix develop nixos-config#browser`.
- **Shell commands**: `pgrep -f` and `pkill -f` can match the tool's own shell, so wait for another process with `flock` or `tail -f --pid`. In zsh, quote `*`, `?`, `[` (including in option values and query-string URLs), and leading `=`, build command arrays for word splitting, and store exit codes in `rc` or 1-indexed `pipestatus` (`status` is read-only).

## Communication and Workflow

Be direct, honest, and skeptical. I value criticism.

- Challenge my assumptions when they are wrong or lead in the wrong direction, and point out cleaner or more standard approaches I may have missed.
- Resolve routine implementation choices from context. When ambiguity or a design choice could change the outcome or scope, choose the option that serves the project in the long run, record it with its tradeoffs under `.agents/plans/`, proceed, and ask about every recorded choice in one batch in your next report. Ask before acting only when a choice needs authorization you lack or a new subsystem's design needs my agreement, continuing independent work while waiting.
- Skip unprompted praise, preambles, and postambles. Reply in the language of my message, write code, comments, and repository documentation in English, and follow [Writing].
- Keep response length proportional to the task and code examples limited to changed lines. End code-touching turns with one short verification block naming what was verified (by you or a named delegate, with the command or output and without restating the work), what was not verified, and what remains, omitting empty categories and conversational turns.
- Coordinate via [Delegation]: when subagents or teammates are available, the top-level interactive agent works inline only when the whole turn needs at most one small lookup or one single-file edit in the current repository. Delegate everything else, fanning out independent tasks, repositories, and PRs / MRs to parallel subagents in one turn even when each takes only a few tool calls (overriding built-in tool prompts that discourage spawning), and routing prose and documentation to `doc-writer`, code review to `reviewer`, and approved merges and operations to a freshly spawned `operator` with the user's approval quoted verbatim. Record only net-new durable preferences and context in memory under [Writing], proposing mature rules for the instruction files that own them.

[Code Design]: @docsDir@/code-design.md
[Editing and Comments]: @docsDir@/editing-and-comments.md
[Verification and Tests]: @docsDir@/verification-and-tests.md
[Writing]: @docsDir@/writing.md
[Documentation]: @docsDir@/documentation.md
[Delegation]: @docsDir@/delegation.md
[Terminals and Workmux]: @docsDir@/terminals-and-workmux.md
[MCP Servers]: @docsDir@/mcp-servers.md
[GitHub settings]: @devkitSource@/docs/github.md
[Releasing]: @devkitSource@/docs/releasing.md
