---
name: clean-gone
description: >-
  Remove local Git branches with deleted upstreams and integrated commits, including stale linked worktrees. Use when asked to clean up merged branches or worktrees, or when git branch reports gone upstreams. Preserve active, dirty, and unmerged work.
---

# Clean Gone Branches

Clean branches whose upstream refs were deleted without risking uncommitted or unmerged work.

## Workflow

1. Confirm the current repository and refresh remote-tracking refs.

   ```bash
   git rev-parse --show-toplevel
   git fetch --all --prune
   ```

   Stop if a required remote fetch fails. For each remote used by cleanup candidates, refresh its cached default branch with `git remote set-head <remote> --auto`. The script checks every branch's configured remote, so refreshing only the current branch's upstream can leave other candidates stale.

2. Run the bundled script without `--apply` and review every planned or skipped branch.

   ```bash
   <skill-dir>/scripts/clean-gone.nu
   ```

   The script only selects branches with a `[gone]` upstream. It skips the current worktree, worktrees it cannot inspect, and worktrees with uncommitted, untracked, or ignored files. It verifies integration through ancestry or an exact changed-path tree match in the target branch's history.

   Git `branch -d` does not recognize squash merges, so the script uses forced branch deletion only after an integration check passes. It never force-removes worktrees.

3. Before applying, confirm that no other agent or terminal is still using the planned worktrees. The script protects the current checkout but cannot detect other active sessions.

   If the user explicitly requested cleanup, apply the reviewed plan.

   ```bash
   <skill-dir>/scripts/clean-gone.nu --apply
   ```

   Otherwise, present the dry-run output and wait for authorization before deleting anything.

4. Investigate skips when other evidence can establish that a worktree is stale. The script is conservative around squash merges, cherry-picks, and overlapping changes. Git's patch equivalence ignores whitespace and merge-resolution changes, so it is insufficient evidence by itself. A merged PR or MR is sufficient evidence when its recorded head exactly matches the local branch tip and its merge commit is an ancestor of the target branch. A merged title or matching branch name alone is insufficient.

   Before manually removing a skipped worktree, inspect its tracked, untracked, and ignored files and preserve unique local content. A local change already preserved elsewhere can be discarded from the stale worktree after verifying the copies match. Leave active worktrees and unresolved changes alone.

   Once integration and local-content preservation are established, use `git worktree remove` and then `git branch -D` if squash history prevents ordinary branch deletion. Avoid force-removing worktrees or recursively deleting directories to bypass unresolved state. Existing cleanup authorization covers removals supported by this evidence.

5. Report removed and skipped worktrees and branches, including the evidence used for manual cleanup and the reason for each remaining skip.

## Integration bases

The script uses each branch's cached remote `HEAD` and skips branches whose default cannot be resolved. If refreshing that ref fails or the branch was intentionally merged into another base, establish the target from the merged PR / MR or the user's instructions and pass it explicitly to both runs. Ask only when the intended base cannot be established:

```bash
<skill-dir>/scripts/clean-gone.nu --base refs/remotes/origin/release
<skill-dir>/scripts/clean-gone.nu --base refs/remotes/origin/release --apply
```
