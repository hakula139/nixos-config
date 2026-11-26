# Terminals and Workmux

Rules for tmux session layout, Workmux worker placement, and interactive assistant panes.

## Terminal Sessions

Keep independent projects in long-lived repository-scoped tmux sessions. Use a coherent workstream or repository-family session only for windows that genuinely share ownership, and reserve additional sessions for genuinely distinct interactive or operational contexts. Name windows for their task or owner.

Once the task is clear, a top-level interactive agent runs `tmux-task-name <short-hyphenated-name>` from its shell tool (delegated, headless, and background runs never call it):

- Single-window numeric session → renames the session.
- Named or multi-window session with an auto-named window → renames the window.
- Multi-pane, Workmux, or already-named window → skips.

Keep native agent conversation and pane titles independent of the tmux session or window name.

Consolidate existing windows only when the user explicitly asks, after checking client attachment and work ownership. Preserve running assistants, their transcripts, and every pane's repository cwd. Never disturb a user's attached active interactive context or close or discard a session with open, unpublished, or otherwise incomplete work. Keep the shared-tree safeguards in force.

## Workmux and Interactive Panes

- **Worktrees**: Create worktrees with Workmux under the `git-workflow` skill, and never use an assistant's built-in worktree feature (`--worktree`, `/worktree`, `create_worktree`, `/wt`, or `omp worktree add`).
- **Worker placement**: When launching a Workmux worker, pass `--agent` for the selected assistant (`codex`, `claude`, or `omp`) to override Workmux's static default. When an existing session is the appropriate hub under [Terminal Sessions](#terminal-sessions), pass `--parent-session <hub>` and `--background` so the worker lands there without stealing focus. Choose a separate session only for a genuinely distinct context.
- **Interactive panes**: After typing or pasting a prompt into an interactive assistant pane, send Enter as a separate keystroke and confirm the task started, since TUI panes can treat a trailing newline in pasted input as literal text and miss the submit.

## Claude Code Isolated Worktrees

Claude Code's worktree features route through Workmux: `--worktree`, `EnterWorktree`, `isolation: "worktree"`, and background sessions create a Workmux worktree beside the checkout and reuse an existing one with the same name. Each gets the handle `<name>` and the branch `worktree-<name>`, and a subagent's worktree stays in place after it finishes for cleanup through `clean-gone`. The hook skips `.worktreeinclude`, and Workmux's `files` configuration copies or symlinks ignored files.

Claude Code runs a guard on Bash and `Monitor` commands inside an isolated agent or session (`isolation: "worktree"`, `EnterWorktree`, `claude --worktree`, and agents spawned inside them):

- **Git**: The guard refuses any command it cannot prove keeps git inside the worktree, including loops, substitutions, heredocs, and text that merely contains `git`, so run each git command on its own.
- **Builtin names**: The guard refuses any command containing a string-running builtin name (`eval`, `source`) in any position, including `nix eval`.
- **Scripts**: Put multi-step logic and any other refused command in a script in the worktree's gitignored build directory, and run the script.
