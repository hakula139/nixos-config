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
   nu <skill-dir>/scripts/clean-gone.nu
   ```

   The script only selects branches with a `[gone]` upstream. It skips the active worktree and dirty worktrees, then verifies integration through ancestry, patch equivalence, or an exact changed-path tree match in the target branch's history.

   Git `branch -d` does not recognize squash merges, so the script uses forced branch deletion only after an integration check passes. It never force-removes worktrees.

3. If the user explicitly requested cleanup, apply the reviewed plan.

   ```bash
   nu <skill-dir>/scripts/clean-gone.nu --apply
   ```

   Otherwise, present the dry-run output and wait for authorization before deleting anything.

4. Investigate skips when other evidence can establish that a worktree is stale. The script is conservative around squash merges and overlapping changes. A merged PR or MR is sufficient evidence when its recorded head exactly matches the local branch tip and its merge commit is an ancestor of the target branch. A merged title or matching branch name alone is insufficient.

   Inspect tracked, untracked, and ignored files before manual cleanup. Preserve unique local content. A local change already preserved elsewhere can be discarded from the stale worktree after verifying the copies match. Leave active worktrees and unresolved changes alone.

   Once integration and local-content preservation are established, use `git worktree remove` and then `git branch -D` if squash history prevents ordinary branch deletion. Avoid force-removing worktrees or recursively deleting directories to bypass unresolved state. Existing cleanup authorization covers removals supported by this evidence.

5. Report removed and skipped worktrees and branches, including the evidence used for manual cleanup and the reason for each remaining skip.

## Non-default bases

The script discovers each branch's remote default branch. If the deleted branch was intentionally merged into another base, verify that base with the user and pass it explicitly to both runs:

```bash
nu <skill-dir>/scripts/clean-gone.nu --base origin/release
nu <skill-dir>/scripts/clean-gone.nu --base origin/release --apply
```
