---
name: clean-gone
description: Safely remove local Git branches whose configured upstreams are gone and whose commits are integrated into the remote default branch, including linked worktrees. Use after merged remote branches are deleted, when `git branch` shows `[gone]`, or when the user asks to prune stale branches or worktrees. Preserve active, dirty, and unmerged work.
---

# Clean Gone Branches

Clean branches whose upstream refs were deleted without risking uncommitted or unmerged work.

## Workflow

1. Confirm the current repository and refresh remote-tracking refs.

   ```bash
   git rev-parse --show-toplevel
   git fetch --prune
   ```

   Stop if the fetch fails. A stale remote-tracking ref can hide that a branch is gone.

2. Run the bundled script without `--apply` and review every planned or skipped branch.

   ```bash
   bash <skill-dir>/scripts/clean-gone.sh
   ```

   The script only selects branches with a `[gone]` upstream. It skips the active worktree, dirty worktrees, and branches that are neither ancestors nor patch-equivalent to the remote default branch.

   For squash merges, the script requires `git cherry` to report every branch commit as patch-equivalent. Git `branch -d` does not recognize squash merges, so the script uses forced branch deletion only after this integration check passes. It never force-removes worktrees.

3. If the user explicitly requested cleanup, apply the reviewed plan.

   ```bash
   bash <skill-dir>/scripts/clean-gone.sh --apply
   ```

   Otherwise, present the dry-run output and wait for authorization before deleting anything.

4. Report removed and skipped worktrees and branches. Explain each skip. Never work around a skip with manual force deletion or directory removal.

## Non-default bases

The script discovers each branch's remote default branch. If the deleted branch was intentionally merged into another base, verify that base with the user and pass it explicitly to both runs:

```bash
bash <skill-dir>/scripts/clean-gone.sh --base origin/release
bash <skill-dir>/scripts/clean-gone.sh --base origin/release --apply
```
