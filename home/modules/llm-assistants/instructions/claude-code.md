## Claude Code

### Tool Use

- **Edit and Write**: The formatter and the comment gate run only on Edit and Write, so use those tools for repository edits even when auto mode suggests `sed` or a heredoc.
- **Subagent writes**: Write refuses a subagent's write when the target is a Markdown file whose name starts with `report`, `summary`, `findings`, or `analysis`, regardless of case. When a delegate must produce such a file, the coordinator creates it first and the delegate fills it in with Edit, so the formatter and the comment gate still run.
- **Web search**: Native `WebSearch` needs a profile that enables it, while `WebFetch` always works.

### Bash Tool

- **`rm`**: Give it literal paths, since Claude Code's safety check asks for approval when a target is a variable or a glob it cannot resolve.
- **Comments**: Never start the `command` field with a shell comment, because that breaks permission pattern matching, and put explanations in the `description` parameter.

### Isolated Worktrees

Claude Code's worktree features route through Workmux: `--worktree`, `EnterWorktree`, `isolation: "worktree"`, and background sessions create a Workmux worktree beside the checkout and reuse an existing one with the same name. Each gets the handle `<name>` and the branch `worktree-<name>`. A subagent's worktree is kept after it finishes. Use the `clean-gone` skill to review and clean up finished worktrees. `.worktreeinclude` is not processed, because the hook replaces the built-in creation. Workmux's `files` configuration copies or symlinks ignored files instead.

Claude Code runs a guard on Bash and `Monitor` commands only in an isolated agent or session: an agent spawned with `isolation: "worktree"`, a session opened with `EnterWorktree` or `claude --worktree`, and the agents spawned inside either.

- **Git**: The guard refuses any command it cannot prove keeps git inside the worktree, including loops, substitutions, heredocs, and text that merely contains `git`, so run each git command on its own.
- **Builtin names**: The guard also refuses any command with a word in any position that names a string-running builtin such as `eval` or `source`, so `nix eval` is refused too.
- **Scripts**: Put multi-step logic and any other refused command in a script in the worktree's gitignored build directory, and run the script.

### Agents and Waiting

- **Delegation**: Use subagents for independent tasks and Agent Teams when peers need shared task state or direct messaging.
- **Parallel writers**: Isolate them with `Agent({ isolation: "worktree" })`.
- **Spawned agents**: A subagent spawning another agent omits `name` so that the new agent reports back to it, because in a team session a named agent joins the main session's team and reports to the team lead.
- **Teammates**: Never brief a teammate to reply without tools. Its plain text never reaches the coordinator and `SendMessage` is itself a tool, so neither side can proceed, and repeated empty idle notifications are the sign of that deadlock.
- **Waiting**: End the turn when nothing else is pending, because Claude Code resumes you when a background subagent completes or a `run_in_background` Bash command exits. Run each background wait as one such command, and reserve a `Monitor` watch for streams whose individual events matter, as it resumes you on every output line.

### Compaction

During compaction, preserve the current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, reread the project's AGENTS.md before continuing.
