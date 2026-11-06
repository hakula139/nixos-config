---
name: clean-gone
description: >-
  Remove finished local Git branches and stale linked worktrees with the `clean-gone` command,
  moving agent memory into the main checkout. Use when asked to clean up merged branches or
  worktrees, after a PR / MR merges or closes, or when git branch reports gone upstreams.
---

# Clean Gone Branches

Remove finished branches and stale worktrees while protecting work in progress. The `clean-gone` command applies its plan by default. To discard an unwanted worktree, follow the `git-workflow` skill.

## Workflow

1. Confirm the repository and refresh remote-tracking refs, since unpublished commits and gone upstreams are judged against the last fetch. Stop if any required fetch fails.

   ```bash
   git rev-parse --show-toplevel
   git fetch --all --prune
   ```

2. Run `clean-gone` as its own command to sweep the repository. Preview with `--dry-run` when unsure. A raw `git worktree remove` leaves its branch behind and skips the agent-memory move, so let `clean-gone` remove finished worktrees.

   It prunes worktrees whose directory is gone, first unlocking any that an exited session or this session locked, and skips a missing one that another lock holds. Then it checks every other linked worktree except the current one. It skips a worktree that a running process or another live session's lock holds, and one that this session's lock holds unless its branch is finished. Before removing a worktree, it moves the ignored files under its `.claude/agent-memory-local/` and `.agents/plans/` into the main checkout, copying missing files and appending missing lines without overwriting anything. Then:

   - **Finished**: the newest PR / MR of the branch is merged or closed, and its head contains the branch tip. The worktree is removed even with uncommitted work, and the branch is deleted.
   - **Open PR / MR**: the worktree is kept untouched.
   - **Uncommitted work**: the worktree is skipped with the age of its newest change.
   - **Idle for over a day**: a clean detached worktree is removed when a branch or remote-tracking ref holds its HEAD. A clean worktree on a branch is removed, and its branch is deleted only when every commit is on a remote.
   - **No worktree**: a finished branch is deleted, and so is one without an open PR / MR whose commits are all on a remote once its last commit is over a day old. A branch with unpublished commits is never deleted, and it is skipped for review once its upstream is gone or its last commit is over a day old.

3. Follow up on each line that ends with "Review whether it needs an MR." Inspect each flagged item, then open an MR for work worth keeping, under the standing authority for follow-up changes in a repository you already publish to, or report it to the user. Never discard uncommitted work unless the user names it.

4. Report the worktrees and branches removed or skipped and the reason for each remaining skip. Removing a skipped worktree or branch another way needs the user's approval.
