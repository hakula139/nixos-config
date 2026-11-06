#!/usr/bin/env nu

# ==================================================================================================
# Worktree Create Hook
# ==================================================================================================
# Claude Code hands this hook the worktree name and the session's working directory, and reads the
# absolute path it prints as the worktree to enter. Workmux records the handle, branch, and base
# for later cleanup.
# ==================================================================================================

# The commit a new worktree branches from, without fetching.
def base-ref [cwd: string]: nothing -> string {
  let remote = (
    ^git
      -C $cwd
      rev-parse
        --abbrev-ref origin/HEAD
    | complete
  )
  if $remote.exit_code == 0 {
    $remote.stdout | str trim
  } else {
    ^git -C $cwd rev-parse HEAD | str trim
  }
}

def main [] {
  let input = (^cat | from json)
  cd $input.cwd

  let existing = (^workmux path $input.name | complete)
  let reuse = (
    $existing.exit_code == 0
    and (($existing.stdout | str trim | path basename) == $input.name)
  )
  if $reuse {
    print ($existing.stdout | str trim)
    return
  }

  let base = (base-ref $input.cwd)
  # Like Claude's built-in creation, skip repository-defined post-create hooks.
  print (
    ^workmux add $"worktree-($input.name)"
      --base $base
      --name $input.name
      --no-hooks
      --headless
      --json
    | from json
    | get worktree_path
  )
}
