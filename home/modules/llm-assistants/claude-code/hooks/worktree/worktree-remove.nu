#!/usr/bin/env nu

# ==================================================================================================
# Worktree Remove Hook
# ==================================================================================================
# Claude Code calls this for a worktree its create hook made. Workmux removes the directory and its
# branch together, and the hook fails while the directory survives.
# ==================================================================================================

def main [] {
  let input = (^cat | from json)
  let worktree = $input.worktree_path

  if not ($worktree | path exists) { exit 0 }

  do { cd $worktree; ^workmux remove --force ($worktree | path basename) }
  if ($worktree | path exists) { exit 1 }
}
