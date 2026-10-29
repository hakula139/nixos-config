## Claude Code

### Tool Use

- **Edit and Write**: the formatter and the comment gate run only on Edit and Write, so use those tools for repository edits even when auto mode suggests `sed` or a heredoc.
- **Bash**: never start the `command` field with a shell comment because that breaks permission pattern matching. Put explanations in the `description` parameter.
- **Web search**: native `WebSearch` needs a profile that enables it, while `WebFetch` always works.

### Isolated Worktrees

Claude Code runs a guard on Bash and `Monitor` commands only in an isolated agent or session: an agent spawned with `isolation: "worktree"`, a session opened with `EnterWorktree` or `claude --worktree`, and the agents spawned inside either.

- **Git**: the guard refuses any command it cannot prove keeps git inside the worktree, including loops, substitutions, heredocs, and text that merely contains `git`, so run each git command on its own.
- **Builtin names**: it also refuses any command with a word in any position that names a string-running builtin such as `eval` or `source`, so `nix eval` is refused too.
- **Scripts**: put multi-step logic and any other refused command in a script in the worktree's gitignored build directory, and run the script.

### Agents and Waiting

- **Delegation**: use subagents for independent tasks and Agent Teams when peers need shared task state or direct messaging.
- **Parallel writers**: isolate them with `Agent({ isolation: "worktree" })`.
- **Spawned agents**: a subagent spawning another agent omits `name` so that the new agent reports back to it, because in a team session a named agent joins the main session's team and reports to the team lead.
- **Teammates**: never brief a teammate to reply without tools. Its plain text never reaches the coordinator and `SendMessage` is itself a tool, so neither side can proceed, and repeated empty idle notifications are the sign of that deadlock.
- **Waiting**: end the turn when nothing else is pending, because the harness resumes you when a background subagent completes or a `run_in_background` Bash command exits. Run each background wait as one such command, and reserve a `Monitor` watch for streams whose individual events matter, as it resumes you on every output line.

### Compaction

During compaction, preserve the current task state, modified files, architecture decisions, code style requirements, and unresolved issues. After compaction, reread the project's AGENTS.md before continuing.
