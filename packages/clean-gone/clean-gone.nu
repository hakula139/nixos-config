#!/usr/bin/env nu

# ==================================================================================================
# Clean Gone
# ==================================================================================================
# Remove finished local branches and stale linked worktrees after moving each worktree's ignored
# agent memory and plans into the main checkout. Remote branches are never deleted.
#
# Run with --help for usage.
# ==================================================================================================

const AGENT_DIRS = [".claude/agent-memory-local" ".agents/plans"]
const IDLE_AFTER = 1day
const GITHUB_HOSTS = ["github.com" "ssh.github.com"]

# --------------------------------------------------------------------------------------------------
# Git helpers
# --------------------------------------------------------------------------------------------------

def --wrapped git-out [...args: string]: nothing -> string {
  let r = (^git ...$args | complete)
  if $r.exit_code == 0 {
    $r.stdout | str trim
  } else {
    ""
  }
}

def --wrapped nul-list [...args: string]: nothing -> list<string> {
  ^git ...$args
  | split row (char nul)
  | where $it != ""
}

def --wrapped commit-count [...args: string]: nothing -> int {
  git-out rev-list --count ...$args | into int
}

# The non-blank lines of `text`, trimmed, since glab pads its error box with spaces.
def error-lines [text: string]: nothing -> list<string> {
  $text
  | lines
  | str trim
  | where $it != ""
}

def plural [count: int, noun: string]: nothing -> string {
  if $count == 1 { $"1 ($noun)" } else { $"($count) ($noun)s" }
}

def die [msg: string] {
  print -e $"error: ($msg)"
  exit 2
}

# --------------------------------------------------------------------------------------------------
# Worktrees and branches
# --------------------------------------------------------------------------------------------------

# A blank field terminates each worktree's block, so the split into blocks has to happen before
# empty fields are dropped.
def worktree-records []: nothing -> list<record> {
  (
    ^git worktree list
      --porcelain
      -z
    | split row (char nul)
    | split list ""
    | where {|block| $block | is-not-empty }
    | each {|block|
      let fields = (
        $block
        | reduce --fold {} {|field, acc|
          let parts = ($field | split row --number 2 " ")
          $acc | insert $parts.0 ($parts | get -o 1 | default "")
        }
      )
      {
        path: $fields.worktree
        head: ($fields.HEAD? | default "")
        branch: ($fields.branch? | default "" | str replace "refs/heads/" "")
        locked: $fields.locked?
        prunable: ("prunable" in $fields)
      }
    }
  )
}

def local-branches []: nothing -> list<record> {
  (
    ^git for-each-ref refs/heads/
      --format="%(refname:strip=2)%09%(upstream:track)"
    | lines
    | parse "{name}\t{tracking}"
    | insert gone {|row| $row.tracking | str contains "gone" }
  )
}

# Tracked changes and untracked files, as absolute paths. Ignored files do not count.
def changed-files [worktree: string]: nothing -> list<string> {
  let tracked = (
    nul-list
      -C $worktree
      diff HEAD
        --name-only
        --no-renames
        -z
  )
  let untracked = (
    nul-list
      -C $worktree
      ls-files
        --others
        --exclude-standard
        -z
  )
  $tracked ++ $untracked | each {|file| $worktree | path join $file }
}

# The age of the newest changed file, or of the worktree directory when every change is a deletion.
def last-touched [worktree: string, files: list<string>]: nothing -> string {
  let existing = ($files | where {|file| $file | path exists })
  let paths = (if ($existing | is-empty) { [$worktree] } else { $existing })
  (
    $paths
    | each {|file| ls -D $file | get 0.modified }
    | sort
    | last
    | date humanize
  )
}

def commit-date [rev: string]: nothing -> datetime {
  (
    git-out log $rev
      -1
      --format=%ct
    | into datetime --format "%s"
  )
}

# The newer of the last commit and the index's last write, which checkouts and staging update.
def last-activity [worktree: record]: nothing -> datetime {
  let index = (
    git-out -C $worktree.path rev-parse
      --path-format=absolute
      --git-path index
  )
  [(commit-date $worktree.head) (ls -D $index | get 0.modified)] | math max
}

# --------------------------------------------------------------------------------------------------
# Locks and processes
# --------------------------------------------------------------------------------------------------

# The files the user's processes hold open, cwd included, as `pid`, `command`, and `name` rows.
# Without them no worktree can be shown unused, so a failed listing ends the run.
def open-files []: nothing -> list {
  let listing = (
    ^lsof
      -n
      -P
      -w
      -u (^id -u | str trim)
      -F pcn
    | complete
  )
  if $listing.exit_code != 0 {
    die (
      error-lines $listing.stderr
      | prepend "listing open files failed"
      | str join "\n    "
    )
  }

  # `-F pcn` prints a `p` and a `c` line per process, then `f` and `n` lines per file.
  mut pid = ""
  mut command = ""
  mut files: list<record> = []
  for line in ($listing.stdout | lines) {
    let value = ($line | str substring 1..)
    match ($line | str substring 0..<1) {
      "p" => { $pid = $value }
      "c" => { $command = $value }
      "n" => {
        $files = (
          $files
          | append {
            pid: $pid
            command: $command
            name: $value
          }
        )
      }
    }
  }
  $files
}

def holders [files: list<record>, path: string]: nothing -> list<string> {
  let prefix = $path + "/"
  (
    $files
    | where {|file| $file.name == $path or ($file.name | str starts-with $prefix) }
    | each {|file| $"($file.pid) ($file.command)" }
    | uniq
  )
}

# Pid 1 is every process's ancestor, so it never marks a lock as the calling session's.
def ancestor-pids [snapshot: list<record>, start: int]: nothing -> list<int> {
  mut current = $start
  mut result: list<int> = []
  while $current not-in [0 1] {
    if ($current not-in $snapshot.pid) { break }
    $result = ($result | append $current)
    $current = ($snapshot | where pid == $current | get ppid | first)
  }
  $result
}

# Whose lock holds a worktree: `none`, an exited Claude Code session (`stale`), or the session
# calling this command (`own`). Claude Code writes `claude agent agent-<id> (pid <N> start <S>)`,
# and any other lock, or one naming another live session, is a `problem`.
def lock-state [locked: oneof<string, nothing>, context: record]: nothing -> record {
  if $locked == null {
    return {kind: "none"}
  }

  let parsed = ($locked | parse --regex '^claude .*\(pid (?<pid>\d+)(?: start \d+)?\)$')
  if ($parsed | is-empty) {
    let problem = (
      if ($locked | is-empty) {
        "is locked without a reason"
      } else {
        $"is locked: ($locked)"
      }
    )
    return {problem: $problem}
  }

  let pid = ($parsed.0.pid | into int)
  if $pid not-in $context.processes.pid {
    return {kind: "stale"}
  }
  if $pid in $context.ancestors {
    return {
      kind: "own"
      pid: $pid
    }
  }
  {problem: $"is locked by another running session \(pid ($pid)\)"}
}

# --------------------------------------------------------------------------------------------------
# Forge
# --------------------------------------------------------------------------------------------------

# The origin's configured URL, before `insteadOf` rewrites it, taking the first of several values.
def configured-origin []: nothing -> string {
  (
    git-out config --get-all remote.origin.url
    | lines
    | first
    | default ""
  )
}

# The scheme, user, host, and path of `url`, from a URL or an scp-like `host:path`.
def remote-parts [url: string]: nothing -> record {
  if ($url =~ '://') {
    let parts = ($url | url parse)
    {
      scheme: ($parts | get -o scheme | default "")
      user: ($parts | get -o username | default "")
      host: ($parts | get -o host | default "")
      path: ($parts | get -o path | default "")
    }
  } else {
    let match = ($url | parse --regex '^(?:(?<user>[^@/]+)@)?(?<host>[^/:]+):(?<path>.*)$')
    if ($match | is-empty) {
      {
        scheme: ""
        user: ""
        host: ""
        path: ""
      }
    } else {
      {
        scheme: ""
        user: ($match.0 | get -o user | default "")
        host: $match.0.host
        path: $match.0.path
      }
    }
  }
}

# Whether the parsed remote `parts` uses an SSH transport: an scp-like `host:path`, or an ssh-based
# URL scheme.
def ssh-transport [parts: record]: nothing -> bool {
  if ($parts.scheme | is-empty) { return true }
  $parts.scheme in ["ssh" "git+ssh" "ssh+git"]
}

# Whether the parsed remote `parts` names a repository on GitHub, resolving SSH host aliases through
# `ssh -G` for SSH transports. Fails when `ssh -G` rejects the configuration.
def github-remote [parts: record]: nothing -> bool {
  let host = (
    if ($parts.host | is-empty) or not (ssh-transport $parts) {
      $parts.host
    } else {
      let target = (
        if ($parts.user | is-empty) {
          $parts.host
        } else {
          $"($parts.user)@($parts.host)"
        }
      )
      let run = (^ssh -G $target | complete)
      if $run.exit_code != 0 {
        die (
          error-lines $run.stderr
          | prepend $"resolving ($target) through ssh failed"
          | str join "\n    "
        )
      }
      (
        $run.stdout
        | lines
        | parse --regex '^hostname\s+(?<host>\S+)$'
        | get host
        | first
      )
    }
  )
  $host in $GITHUB_HOSTS
}

# --------------------------------------------------------------------------------------------------
# Requests
# --------------------------------------------------------------------------------------------------

# Whether the requests on `origin` from `branch` make it `open`, `finished`, or `unfinished`, or the
# `problem` that leaves it unknown. Any open request keeps it open. Otherwise it is finished when
# its newest request is merged or closed and that request's head contains the branch tip, since a
# later tip holds unreviewed work. `gh` reads the requests from the context's slug, since it cannot
# resolve a remote that `insteadOf` rewrites.
def branch-status [branch: string, context: record]: nothing -> record {
  let run = (
    if $context.github {
      (
        ^gh pr list
          --repo $context.slug
          --head $branch
          --state all
          --json number,state,headRefOid
        | complete
      )
    } else {
      (
        ^glab mr list
          --source-branch $branch
          --all
          --output json
        | complete
      )
    }
  )
  if $run.exit_code != 0 {
    return {
      problem: "looking up its requests failed"
      details: (error-lines $run.stderr)
    }
  }

  let requests = (
    $run.stdout
    | from json
    | rename --column (if $context.github { {headRefOid: sha} } else { {iid: number} })
    | update state {|request| $request.state | str lowercase | str replace "opened" "open" }
  )
  if ($requests | where state == "open" | is-not-empty) {
    return {state: "open"}
  }

  let newest = ($requests | sort-by number | last)
  if ($newest == null) or ($newest.state not-in ["merged" "closed"]) {
    return {state: "unfinished"}
  }
  let contained = (^git merge-base --is-ancestor $"refs/heads/($branch)" $newest.sha | complete)
  if $contained.exit_code != 0 {
    return {state: "unfinished"}
  }

  let prefix = (if $context.github { "pull request #" } else { "merge request !" })
  {
    state: "finished"
    evidence: $"($prefix)($newest.number) is ($newest.state)"
  }
}

# --------------------------------------------------------------------------------------------------
# Agent files
# --------------------------------------------------------------------------------------------------

# Copies each ignored file under the agent directories that the main checkout lacks, and appends to
# each differing copy the lines it lacks, so the main checkout's copies only grow.
def agent-file-moves [worktree: string, main: string]: nothing -> list<record> {
  (
    nul-list
      -C $worktree
      ls-files
        --others
        --ignored
        --exclude-standard
        -z
        --
        ...$AGENT_DIRS
    | where {|rel| ($worktree | path join $rel | path type) == "file" }
    | each {|rel|
      let file = ($worktree | path join $rel)
      let target = ($main | path join $rel)
      if not ($target | path exists) {
        return {
          kind: "copy"
          rel: $rel
          source: $file
          target: $target
        }
      }

      let existing = (open --raw $target | into string | lines)
      let missing = (
        open --raw $file
        | into string
        | lines
        | where {|line| ($line | str trim) != "" and $line not-in $existing }
        | uniq
      )
      if ($missing | is-not-empty) {
        {
          kind: "merge"
          rel: $rel
          target: $target
          lines: $missing
        }
      }
    }
    | compact
  )
}

def move-text [move: record]: nothing -> string {
  if $move.kind == "copy" {
    $"copy ($move.rel) to the main checkout"
  } else {
    $"append (plural ($move.lines | length) 'new line') to ($move.rel) in the main checkout"
  }
}

def apply-move [move: record]: nothing -> nothing {
  if $move.kind == "copy" {
    mkdir ($move.target | path dirname)
    ^cp $move.source $move.target
    return
  }

  let existing = (open --raw $move.target | into string)
  let terminated = ($existing | is-empty) or ($existing | str ends-with "\n")
  let separator = (if $terminated { "" } else { "\n" })
  ($separator + ($move.lines | str join "\n") + "\n") | save --append $move.target
}

# --------------------------------------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------------------------------------

def print-skip [subject: string, problem: string, details: list<string> = []]: nothing -> nothing {
  print $"SKIP ($subject): ($problem)"
  for detail in $details {
    print $"    ($detail)"
  }
}

# Prints `git ...args` under `subject` as a PLAN line in a dry run, and otherwise runs it and prints
# it as a DONE line. Returns whether it succeeded.
def --wrapped step [subject: string, dry_run: bool, ...args: string]: nothing -> bool {
  let text = (["git"] ++ $args | str join " ")
  if $dry_run {
    print $"PLAN ($subject): ($text)"
    return true
  }

  let run = (^git ...$args | complete)
  if $run.exit_code != 0 {
    print-skip $subject $"($text) failed" (error-lines $run.stderr)
    return false
  }
  print $"DONE ($subject): ($text)"
  true
}

# Removes `worktree` for `reason` after moving its agent files, deleting its branch with `--delete`
# and its uncommitted work with `--force`. Returns `clean` or `skip`.
def remove-worktree [
  worktree: record
  lock: record
  context: record
  reason: string
  --delete
  --force
]: nothing -> string {
  let path = $worktree.path
  print $"CLEAN ($path): ($reason)"
  let tag = (if $context.dry_run { "PLAN" } else { "DONE" })
  for move in (agent-file-moves $path $context.main) {
    if not $context.dry_run {
      apply-move $move
    }
    print $"($tag) ($path): (move-text $move)"
  }

  let steps = [
    (if $lock.kind != "none" { [worktree unlock $path] })
    (if $force { [worktree remove --force $path] } else { [worktree remove $path] })
    (if $delete { [branch -D -- $worktree.branch] })
  ]
  for args in ($steps | compact) {
    if not (step $path $context.dry_run ...$args) {
      return "skip"
    }
  }
  "clean"
}

# Cleans a linked worktree as `main`'s help describes. Returns `clean`, `skip`, or `keep`.
def clean-worktree [worktree: record, context: record]: nothing -> string {
  let path = $worktree.path
  let lock = (lock-state $worktree.locked $context)
  if not ($path | path exists) {
    if "problem" in $lock {
      print-skip $path "its directory is missing"
      return "skip"
    }
    print $"CLEAN ($path): its directory is missing"
    let unlocked = (step $path $context.dry_run worktree unlock $path)
    let pruned = ($unlocked and (step $path $context.dry_run worktree prune))
    return (if $pruned { "clean" } else { "skip" })
  }

  let users = (holders $context.open_files $path)
  if ($users | is-not-empty) {
    print-skip $path "is in use by running processes" $users
    return "skip"
  }
  if "problem" in $lock {
    print-skip $path $lock.problem
    return "skip"
  }

  let branch = $worktree.branch
  let status = (
    if ($branch | is-empty) {
      {state: "detached"}
    } else {
      branch-status $branch $context
    }
  )
  if "problem" in $status {
    print-skip $path $status.problem $status.details
    return "skip"
  }
  if $status.state == "finished" {
    return (remove-worktree $worktree $lock $context $status.evidence --delete --force)
  }
  if $lock.kind == "own" {
    print-skip $path $"is locked by this session \(pid ($lock.pid)\)"
    return "skip"
  }
  if $status.state == "open" {
    return "keep"
  }

  # Git can rewrite the index while listing changes, so its age is read first.
  let idle = ((date now) - (last-activity $worktree)) > $IDLE_AFTER
  let changed = (changed-files $path)
  if ($changed | is-not-empty) {
    let age = (last-touched $path $changed)
    print-skip $path $"uncommitted work, last touched ($age). Review whether it needs an MR."
    return "skip"
  }
  if not $idle {
    return "keep"
  }

  let age = (commit-date $worktree.head | date humanize)
  if ($branch | is-empty) {
    let loose = (
      commit-count $worktree.head
        --not
        --branches
        --tags
        --remotes
    )
    if $loose > 0 {
      let commits = (plural $loose "commit")
      let problem = $"detached HEAD with ($commits) on no ref, last commit ($age)"
      print-skip $path $"($problem). Review whether it needs an MR."
      return "skip"
    }
    return (remove-worktree $worktree $lock $context $"detached HEAD on a ref, last commit ($age)")
  }

  let unpublished = (
    commit-count $"refs/heads/($branch)"
      --not
      --remotes
  )
  if $unpublished == 0 {
    let reason = $"every commit is on a remote, last commit ($age)"
    return (remove-worktree $worktree $lock $context $reason --delete)
  }
  let commits = (plural $unpublished "unpublished commit")
  let reason = $"($commits), last commit ($age), so branch ($branch) stays"
  remove-worktree $worktree $lock $context $"($reason). Review whether it needs an MR."
}

# Cleans an unchecked-out branch as `main`'s help describes. Returns `clean`, `skip`, or `keep`.
def clean-branch [branch: record, context: record]: nothing -> string {
  let name = $branch.name
  let status = (branch-status $name $context)
  if "problem" in $status {
    print-skip $name $status.problem $status.details
    return "skip"
  }
  if $status.state == "open" {
    return "keep"
  }

  let ref = $"refs/heads/($name)"
  let unpublished = (
    commit-count $ref
      --not
      --remotes
  )
  let date = (commit-date $ref)
  let age = ($date | date humanize)
  let idle = ((date now) - $date) > $IDLE_AFTER
  let reason = (
    if $status.state == "finished" {
      $status.evidence
    } else if $unpublished == 0 and $idle {
      $"every commit is on a remote, last commit ($age)"
    }
  )
  if $reason != null {
    print $"CLEAN ($name): ($reason)"
    let deleted = (step $name $context.dry_run branch -D -- $name)
    return (if $deleted { "clean" } else { "skip" })
  }

  if $unpublished > 0 and ($branch.gone or $idle) {
    let gone = (if $branch.gone { "its upstream is gone, " } else { "" })
    let commits = (plural $unpublished "unpublished commit")
    print-skip $name $"($gone)($commits), last commit ($age). Review whether it needs an MR."
    return "skip"
  }
  "keep"
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Remove finished local branches and stale linked worktrees, after moving each worktree's ignored
# files under `.claude/agent-memory-local/` and `.agents/plans/` into the main checkout without
# overwriting anything there.
#
# It prunes worktrees whose directory is gone, unlocking those locked by an exited session or this
# one, then checks the rest except the current one. One that a running process or a live session's
# lock holds is skipped, unless the lock is this session's and the branch is finished.
#
# - Finished: the newest request of the branch is merged or closed and contains its tip. The
#   worktree is removed even with uncommitted work, and the branch is deleted.
# - Open request: the worktree is kept.
# - Uncommitted work: the worktree is skipped.
# - Idle for over a day: a detached worktree is removed when a ref holds its HEAD. A worktree on a
#   branch is removed, and its branch is deleted when every commit is on a remote.
#
# A branch checked out nowhere is deleted when it is finished. Without an open request, one whose
# last commit is over a day old is deleted when every commit is on a remote and skipped otherwise,
# as is a gone upstream with unpublished commits. Remote branches are never deleted. Exits with
# status 1 when anything is skipped.
def main [
  --dry-run # Report the plan without changing anything
] {
  let current = (git-out rev-parse --show-toplevel)
  if ($current | is-empty) {
    die "run this command inside a Git worktree"
  }

  let open_files = (open-files)
  if not $dry_run {
    ^git worktree prune
  }
  let records = (worktree-records | where not prunable)
  let github_origin = (
    [(configured-origin) (git-out remote get-url origin)]
    | uniq
    | each {|url| remote-parts $url }
    | where {|parts| github-remote $parts }
    | first
  )
  let processes = (ps | select pid ppid)
  let context = {
    main: $records.0.path
    github: ($github_origin != null)
    slug: (
      $github_origin.path?
      | default ""
      | str trim --char "/"
      | str replace --regex '\.git$' ""
    )
    open_files: $open_files
    processes: $processes
    ancestors: (ancestor-pids $processes $nu.pid)
    dry_run: $dry_run
  }

  let worktrees = (
    $records
    | skip 1
    | where path != $current
    | each {|worktree| clean-worktree $worktree $context }
  )
  let checked_out = ($records | get branch)
  let branches = (
    local-branches
    | where name not-in $checked_out
    | each {|branch| clean-branch $branch $context }
  )

  let outcomes = ($worktrees ++ $branches)
  if ($outcomes | all {|outcome| $outcome == "keep" }) {
    print "Nothing to clean up."
  }
  if "skip" in $outcomes {
    exit 1
  }
}
