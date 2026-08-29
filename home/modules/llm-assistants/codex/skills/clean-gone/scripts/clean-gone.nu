#!/usr/bin/env nu

# ==============================================================================
# Clean Gone Branches
# ==============================================================================
# Remove local branches whose configured upstreams are gone, along with their
# worktrees. Dry run by default.
# ==============================================================================

# ------------------------------------------------------------------------------
# Git helpers
# ------------------------------------------------------------------------------

# Exit code alone, for the git plumbing commands used as predicates.
def git-succeeds [...args: string]: nothing -> bool {
  (^git ...$args | complete).exit_code == 0
}

def git-out [...args: string]: nothing -> string {
  let r = (^git ...$args | complete)
  if $r.exit_code == 0 { $r.stdout | str trim } else { "" }
}

def commit-exists [ref: string]: nothing -> bool {
  git-succeeds "rev-parse" "--verify" "--quiet" $"($ref)^{commit}"
}

def nul-list [...args: string]: nothing -> list<string> {
  ^git ...$args | split row (char nul) | where $it != ""
}

def die [msg: string] {
  print -e $"error: ($msg)"
  exit 2
}

# ------------------------------------------------------------------------------
# Worktrees
# ------------------------------------------------------------------------------

# A blank field terminates each worktree's block, so the split into blocks has
# to happen before empty fields are dropped.
def worktree-map []: nothing -> record {
  ^git worktree list --porcelain -z
  | split row (char nul)
  | split list ""
  | each {|block|
    $block | parse "{key} {value}" | reduce --fold {} {|field, acc|
      $acc | insert $field.key $field.value
    }
  }
  | where {|wt| "branch" in $wt }
  | reduce --fold {} {|wt, acc|
    $acc | insert ($wt.branch | str replace "refs/heads/" "") $wt.worktree
  }
}

# ------------------------------------------------------------------------------
# Base resolution
# ------------------------------------------------------------------------------

def resolve-base [remote: string, base_override: string]: nothing -> string {
  if ($base_override | is-not-empty) {
    return $base_override
  }

  let head = (git-out "symbolic-ref" "--quiet" "--short" $"refs/remotes/($remote)/HEAD")
  if ($head | is-not-empty) and (commit-exists $head) {
    return $head
  }

  for candidate in [$"($remote)/main" $"($remote)/master"] {
    if (commit-exists $candidate) {
      return $candidate
    }
  }

  ""
}

# ------------------------------------------------------------------------------
# Integration check
# ------------------------------------------------------------------------------

# Three ways to count as integrated: ancestry, patch equivalence, or a
# first-parent commit on the base matching content for the touched paths. Only
# the last recognizes a squash merge.
def branch-is-integrated [branch: string, base_ref: string]: nothing -> bool {
  let branch_ref = $"refs/heads/($branch)"

  if (git-succeeds "merge-base" "--is-ancestor" $branch_ref $base_ref) {
    return true
  }

  let cherry = (^git cherry $base_ref $branch_ref | complete)
  if $cherry.exit_code != 0 {
    return false
  }
  let lines = ($cherry.stdout | lines | where $it != "")
  if ($lines | is-not-empty) and ($lines | where {|l| $l | str starts-with "+" } | is-empty) {
    return true
  }

  let merge_base = (git-out "merge-base" $base_ref $branch_ref)
  if ($merge_base | is-empty) {
    return false
  }

  # An empty net diff (an add later reverted) is integrated by definition.
  let changed = (nul-list "diff" "--name-only" "--no-renames" "-z" $merge_base $branch_ref)
  if ($changed | is-empty) {
    return true
  }

  # `:(literal)` keeps a path containing `*` or `[` from being read as a glob.
  let pathspecs = ($changed | each {|p| ":\(literal)" + $p })
  let candidates = (
    git-out "rev-list" "--first-parent" $base_ref $"^($merge_base)" | lines | where $it != ""
  )

  for candidate in $candidates {
    if (git-succeeds "diff" "--quiet" $branch_ref $candidate "--" ...$pathspecs) {
      return true
    }
  }

  false
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

# Safely remove local branches whose configured upstreams are gone.
def main [
  --apply # Perform the reported removals instead of only printing them
  --base: string = "" # Override the remote default branch used as the integration base
] {
  let repo_root = (git-out "rev-parse" "--show-toplevel")
  if ($repo_root | is-empty) {
    die "run this script inside a Git worktree"
  }

  if ($base | is-not-empty) and (not (commit-exists $base)) {
    die $"base ref does not resolve to a commit: ($base)"
  }

  let worktrees = (worktree-map)

  let gone = (
    ^git for-each-ref --format='%(refname:short)%09%(upstream:track)%09%(upstream:remotename)' refs/heads/
    | parse "{branch}\t{tracking}\t{remote}"
    | where ($it.tracking | str contains "gone")
  )

  if ($gone | is-empty) {
    print "No local branches have a gone upstream."
    exit 0
  }

  mut removed = 0
  mut skipped = 0

  for row in $gone {
    let branch = $row.branch
    let worktree = ($worktrees | get -o $branch | default "")

    if $worktree == $repo_root {
      print $"SKIP ($branch): branch is active in the current worktree"
      $skipped += 1
      continue
    }

    if ($worktree | is-not-empty) and (
      (git-out "-C" $worktree "status" "--porcelain") | is-not-empty
    ) {
      print $"SKIP ($branch): worktree has uncommitted or untracked changes: ($worktree)"
      $skipped += 1
      continue
    }

    if ($row.remote | is-empty) or ($row.remote == ".") {
      print $"SKIP ($branch): cannot determine a remote default branch"
      $skipped += 1
      continue
    }

    let base_ref = (resolve-base $row.remote $base)
    if ($base_ref | is-empty) {
      print $"SKIP ($branch): remote default branch is unavailable for ($row.remote)"
      $skipped += 1
      continue
    }

    if not (branch-is-integrated $branch $base_ref) {
      print $"SKIP ($branch): branch is not integrated into ($base_ref)"
      $skipped += 1
      continue
    }

    if not $apply {
      if ($worktree | is-not-empty) {
        print $"PLAN ($branch): remove worktree ($worktree) and delete branch \(integrated into ($base_ref)\)"
      } else {
        print $"PLAN ($branch): delete branch \(integrated into ($base_ref)\)"
      }
      continue
    }

    if ($worktree | is-not-empty) and (not (git-succeeds "worktree" "remove" $worktree)) {
      print -e $"SKIP ($branch): failed to remove worktree ($worktree)"
      $skipped += 1
      continue
    }

    # -d cannot recognize squash merges, and integration was verified above.
    let deleted = (^git branch -D -- $branch | complete)
    if $deleted.exit_code == 0 {
      print ($deleted.stdout | str trim)
      $removed += 1
    } else {
      print -e $"SKIP ($branch): Git refused to delete the branch"
      $skipped += 1
    }
  }

  if not $apply {
    print "Dry run only. Re-run with --apply after reviewing the plan."
    exit 0
  }

  ^git worktree prune
  print $"Removed ($removed) branch\(es\); skipped ($skipped) branch\(es\)."

  if $skipped > 0 {
    exit 1
  }
}
