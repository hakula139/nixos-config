---
name: clean-gone
description: >-
  Remove local Git branches with deleted upstreams and integrated commits, including stale linked
  worktrees. Use when asked to clean up merged branches or worktrees, or when git branch reports
  gone upstreams. Preserve active, dirty, and unmerged work.
---

# Clean Gone Branches

Remove branches with deleted upstream refs while protecting uncommitted and unmerged work.

## Workflow

1. Confirm the repository and refresh remote-tracking refs. Stop if any required fetch fails.

   ```bash
   git rev-parse --show-toplevel
   git fetch --all --prune
   ```

   Run `git remote set-head <remote> --auto` for each remote used by the candidates. The script checks each branch's configured remote, so a stale cached default branch can skew its integration check.

2. Run the bundled script without `--apply`, then review every planned and skipped branch.

   ```bash
   <skill-dir>/scripts/clean-gone.nu
   ```

   The script selects only branches whose upstream is marked `[gone]`. It skips the current worktree, worktrees it cannot inspect, and worktrees with uncommitted, untracked, or ignored files. It considers a branch integrated if it is an ancestor of the target branch or its changed-path tree exactly matches a tree in the target branch's history. Since `git branch -d` does not recognize squash merges, the script force-deletes a branch only after that integration check passes. It never force-removes worktrees.

3. Confirm that no other agent or terminal is using the planned worktrees. The script protects only the current checkout and cannot detect other sessions. If the user requested cleanup, or cleanup follows merged work under `git-workflow`, apply the reviewed plan.

   ```bash
   <skill-dir>/scripts/clean-gone.nu --apply
   ```

   Otherwise, present the dry run and wait for authorization.

4. Investigate skips when other evidence suggests they may be stale. The script is conservative around squash merges, cherry-picks, and overlapping changes. Git's patch equivalence ignores whitespace and merge-resolution changes, so patch equivalence alone is insufficient. A merged PR / MR is sufficient evidence when its recorded head exactly matches the local branch tip and its merge commit is an ancestor of the target branch. A merged title or matching branch name is not sufficient.

   Before manually removing a skipped worktree, inspect its tracked, untracked, and ignored files, including files in every submodule, and preserve any unique local content. You may discard a change already preserved elsewhere once you verify that the copies match. Leave active worktrees and unresolved changes alone.

   Once integration and preservation are established, run `git worktree remove`, then `git branch -D` if squash history prevents ordinary deletion. Use `git worktree remove --force` only after verifying integration, confirming that all tracked, untracked, and ignored content in the worktree and every submodule is clean or preserved, and checking that no agent, process, or terminal is using them. This applies to worktrees Git refuses to remove because they contain submodules, and the authorization in step 3 covers it. Never recursively delete directories to bypass unresolved state.

5. Report the worktrees and branches removed or skipped, the evidence for each manual cleanup, and the reason for each remaining skip.

## Integration bases

The script uses each branch's cached remote `HEAD` and skips branches whose default cannot be resolved. If refreshing that ref fails or the branch was intentionally merged into another base, establish the target from the merged PR / MR or the user's instructions, then pass it to both runs. Ask only if you cannot establish the target:

```bash
<skill-dir>/scripts/clean-gone.nu --base refs/remotes/origin/release
<skill-dir>/scripts/clean-gone.nu --base refs/remotes/origin/release --apply
```
