#!/usr/bin/env nu

# ==================================================================================================
# /tmp Cleanup
# ==================================================================================================
# Remove the current user's top-level /tmp entries once nothing inside them has been modified or
# had its status changed within the maximum age. The status change time catches trees copied with
# `cp -a` or rsync, which keep their source's mtime. Entries that a process holds open as a file or
# working directory are kept, as are sockets, pipes, and the tmux and Claude Code runtime dirs.
#
# Run with --help for usage.
# ==================================================================================================

# Runtime dirs that tmux and Claude Code keep for as long as they run, such as `tmux-501`.
const RUNTIME_DIR = '^(claude|tmux)-'

# Top-level entry names under `root` that some process holds open as a file or working directory.
def open-entries [root: string]: nothing -> list<string> {
  let lsof = (^lsof -F n -n -P -w | complete)
  if $lsof.exit_code != 0 {
    error make {msg: $"lsof failed with exit ($lsof.exit_code): ($lsof.stderr | str trim)"}
  }

  let prefix = $"n($root)/"
  $lsof.stdout
  | lines
  | where ($it | str starts-with $prefix)
  | each { str substring ($prefix | str length).. | split row "/" | first }
  | uniq
}

# A traversal error counts as recent, so an unreadable subtree is never removed unseen.
def changed-since [path: string, cutoff: string]: nothing -> bool {
  let found = (
    ^find $path '(' -newermt $cutoff -o -newerct $cutoff ')' -print -quit | complete
  )
  $found.exit_code != 0 or ($found.stdout | is-not-empty)
}

# Remove stale top-level entries that the current user owns under a temporary directory.
def main [
  --root: path = /tmp # Directory whose top-level entries are candidates
  --max-age: duration = 1day # Keep entries with any change more recent than this
  --dry-run # List stale entries without removing them
] {
  let root = ($root | path expand)
  let user = (whoami)
  let cutoff = ((date now) - $max_age | format date "%Y-%m-%d %H:%M:%S%.f %z")
  let in_use = (open-entries $root)

  let stale = (
    ls --all --long $root
    | where type in [dir file symlink] and user == $user
    | where {|e| ($e.name | path basename) !~ $RUNTIME_DIR }
    | where {|e| ($e.name | path basename) not-in $in_use }
    | where {|e| not (changed-since $e.name $cutoff) }
    | select name type modified
  )
  if $dry_run {
    return $stale
  }

  let removed = $stale | each {|e|
    if $e.type == dir {
      ^chmod -R u+w $e.name | complete | ignore
    }
    let rm = (^rm -rf $e.name | complete)
    $e | insert error (if $rm.exit_code == 0 { "" } else { $rm.stderr | str trim })
  }
  let failed = ($removed | where error != "")
  if ($failed | is-not-empty) {
    print --stderr ($failed | table)
    exit 1
  }
  if ($removed | is-not-empty) {
    $removed | reject error
  }
}
