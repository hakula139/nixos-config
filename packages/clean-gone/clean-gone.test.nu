#!/usr/bin/env nu

# ==================================================================================================
# Clean Gone Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "clean-gone.nu")

const MEMORY = ".claude/agent-memory-local"
const PLANS = ".agents/plans"

# --------------------------------------------------------------------------------------------------
# Repositories
# --------------------------------------------------------------------------------------------------

# Runs Git in `dir` and returns its trimmed output, failing the test when Git fails.
def --wrapped git-in [dir: string, ...args: string]: nothing -> string {
  let run = (^git -C $dir ...$args | complete)
  assert equal $run.exit_code 0 $"git ($args | str join ' '): ($run.stderr)"
  $run.stdout | str trim
}

# Creates a bare `origin` and its clone `app`, holding one pushed commit from 3 days ago that
# ignores agent memory, plans, and logs, with Git isolated from the host's configuration. Its `bin`
# runs the forge stub as both `glab` and `gh`.
def --env make-repo []: nothing -> record {
  let root = (mktemp --directory | path expand)
  let config = ($root | path join "gitconfig")
  touch $config
  load-env {
    GIT_CONFIG_GLOBAL: $config
    GIT_CONFIG_NOSYSTEM: "1"
    GIT_AUTHOR_NAME: "Example Author"
    GIT_AUTHOR_EMAIL: "author@example.com"
    GIT_COMMITTER_NAME: "Example Author"
    GIT_COMMITTER_EMAIL: "author@example.com"
  }

  let bin = ($root | path join "bin")
  mkdir $bin
  for name in ["gh" "glab"] {
    ^ln -s ($env.NU_TEST_STUBS | path join "forge") ($bin | path join $name)
  }

  let origin = ($root | path join "origin.git")
  let main = ($root | path join "app")
  (
    ^git init $origin
      --quiet
      --bare
      --initial-branch main
  )
  git-in $root clone $origin $main
  let files = {
    ".gitignore": $"/($MEMORY)/\n/($PLANS)/\n*.log\n"
    "README.md": "app\n"
  }
  with-env {GIT_COMMITTER_DATE: (git-date 3day)} {
    commit-files $main $files "chore: init"
  }
  git-in $main push origin main

  {
    root: $root
    bin: $bin
    origin: $origin
    main: $main
  }
}

# Writes each file in `files`, a record of paths and contents, in `dir` and commits them as
# `subject`, returning the commit.
def commit-files [dir: string, files: record, subject: string]: nothing -> string {
  for file in ($files | transpose path content) {
    $file.content | save --force ($dir | path join $file.path)
  }
  git-in $dir add ...($files | columns)
  git-in $dir commit -m $subject
  git-in $dir rev-parse HEAD
}

# Commits `file` `age` ago in the main checkout on a detached `origin/main` and returns the commit,
# then switches the checkout back to `main`.
def commit-detached [repo: record, file: string, --age: duration = 3day]: nothing -> string {
  git-in $repo.main switch --detach origin/main
  with-env {GIT_COMMITTER_DATE: (git-date $age)} {
    commit-files $repo.main {$file: "content\n"} $"feat: add ($file)"
  }
  let head = (git-in $repo.main rev-parse HEAD)
  git-in $repo.main switch main
  $head
}

# A `GIT_COMMITTER_DATE` that is `age` old.
def git-date [age: duration]: nothing -> string {
  $"@((date now) - $age | format date '%s') +0000"
}

# Adds linked worktree `name` beside the main checkout at `start`, on `branch`, or on `feat/<name>`
# unless `--detach`, and returns its path.
def add-worktree [
  repo: record
  name: string
  --branch: string
  --detach
  --start: string = "origin/main"
]: nothing -> string {
  let path = ($repo.root | path join $name)
  if $detach {
    git-in $repo.main worktree add --detach $path $start
  } else {
    git-in $repo.main worktree add -b ($branch | default $"feat/($name)") $path $start
  }
  $path
}

# Edits a tracked file and adds an untracked one in `worktree`, the newer touched `age` ago.
def make-dirty [worktree: string, age: duration = 1hr]: nothing -> nothing {
  "edited\n" | save --force ($worktree | path join "README.md")
  "draft\n" | save ($worktree | path join "draft.txt")
  set-age ($worktree | path join "README.md") $age
  set-age ($worktree | path join "draft.txt") ($age + 2day)
}

# Ages the index of `worktree`, so it reads as idle once its last commit is old too.
def make-idle [worktree: string]: nothing -> nothing {
  let index = (
    git-in $worktree rev-parse
      --path-format=absolute
      --git-path index
  )
  set-age $index 2day
}

def set-age [path: string, age: duration]: nothing -> nothing {
  ^touch -t ((date now) - $age | format date "%Y%m%d%H%M.%S") $path
}

# Pushes `branch` from the main checkout with an upstream, then deletes it on `origin` and prunes
# it locally, so its upstream reads as gone.
def make-gone [repo: record, branch: string]: nothing -> nothing {
  git-in $repo.main push -u origin $branch
  git-in $repo.origin branch -D $branch
  git-in $repo.main fetch --prune | ignore
}

# A GitLab merge request in `glab mr list --output json` form.
def mr [iid: int, branch: string, state: string, sha: string]: nothing -> record {
  {
    iid: $iid
    source_branch: $branch
    state: $state
    sha: $sha
  }
}

# The pid of a process that has already exited.
def dead-pid []: nothing -> int {
  (
    ^$nu.current-exe
      --no-config-file
      --commands "print $nu.pid"
    | str trim
    | into int
  )
}

def claude-lock [pid: int]: nothing -> string {
  $"claude agent agent-a1b2c3d4 \(pid ($pid) start 1730800000\)"
}

# `lsof -F pcn` output for `processes`, each with a `pid`, a `command`, and the `files` it holds.
def lsof-listing [processes: list<record>]: nothing -> string {
  (
    $processes
    | each {|process|
      $process.files
      | enumerate
      | each {|file| [$"f($file.index)" $"n($file.item)"] }
      | prepend [$"p($process.pid)" $"c($process.command)"]
    }
    | flatten
    | flatten
    | str join "\n"
  )
}

# --------------------------------------------------------------------------------------------------
# Runs and state
# --------------------------------------------------------------------------------------------------

# Runs the command in `cwd` with the forge listing `requests` or failing with `forge_error`, `lsof`
# printing `open` or failing with `lsof_exit`, and `ssh -G` resolving `ssh_hostnames` or failing
# with `ssh_error` and `ssh_exit`.
def clean [
  repo: record
  --cwd: string
  --dry-run
  --requests: list<record> = []
  --forge-error: string = ""
  --open: string = ""
  --lsof-exit: int = 0
  --ssh-hostnames: record = {}
  --ssh-error: string = ""
  --ssh-exit: int = 0
]: nothing -> record {
  let argv = (if $dry_run { ["--dry-run"] } else { [] })
  let log = (mktemp)
  let run = with-env {
    PATH: ($env.PATH | prepend [$repo.bin $env.NU_TEST_STUBS])
    STUB_FORGE_ERROR: $forge_error
    STUB_LOG: $log
    STUB_LSOF_EXIT: ($lsof_exit | into string)
    STUB_LSOF_OUTPUT: $open
    STUB_REQUESTS: ($requests | to json --raw)
    STUB_SSH_ERROR: $ssh_error
    STUB_SSH_EXIT: ($ssh_exit | into string)
    STUB_SSH_HOSTNAMES: ($ssh_hostnames | to json --raw)
  } {
    cd ($cwd | default $repo.main)
    ^$nu.current-exe --no-config-file $SCRIPT ...$argv | complete
  }
  let calls = (open $log | from json --objects)
  $run
  | insert lines ($run.stdout | lines)
  | insert calls $calls
}

def worktrees [repo: record]: nothing -> list<string> {
  (
    git-in $repo.main worktree list --porcelain
    | lines
    | where {|line| $line starts-with "worktree " }
    | each {|line| $line | str replace "worktree " "" }
  )
}

def has-branch [repo: record, branch: string]: nothing -> bool {
  (git-in $repo.main branch --list $branch) | is-not-empty
}

def assert-kept [repo: record, path: string, branch: string, case: string]: nothing -> nothing {
  assert ($path | path exists) $case
  assert ($path in (worktrees $repo)) $case
  if ($branch | is-not-empty) {
    assert (has-branch $repo $branch) $case
  }
}

def assert-removed [repo: record, path: string, case: string]: nothing -> nothing {
  assert not ($path | path exists) $case
  assert ($path not-in (worktrees $repo)) $case
}

# The output lines of removing `worktree` for `reason`, with `--force`, after `steps` that precede
# the removal, and deleting `branch` unless it is empty.
def removal [
  worktree: string
  reason: string
  --branch: string = ""
  --force
  --steps: list<string> = []
]: nothing -> list<string> {
  let remove = (if $force { "remove --force" } else { "remove" })
  let delete = (if ($branch | is-empty) { [] } else { [$"git branch -D -- ($branch)"] })
  [$"CLEAN ($worktree): ($reason)"] ++ (
    $steps ++ [$"git worktree ($remove) ($worktree)"] ++ $delete
    | each {|step| $"DONE ($worktree): ($step)" }
  )
}

# --------------------------------------------------------------------------------------------------
# Usage
# --------------------------------------------------------------------------------------------------

def "test errors that leave nothing checkable exit 2 without output" [] {
  let repo = (make-repo)
  let tip = (git-in $repo.main rev-parse origin/main)
  let worktree = (add-worktree $repo "wt")
  let lost = (add-worktree $repo "lost")
  rm --recursive $lost
  let outside = ($repo.root | path join "outside")
  mkdir $outside
  let lsof_error = "lsof: WARNING: can't stat() fuse file system /mnt/example"
  let cases = [
    {
      name: "outside a repository"
      cwd: $outside
      lsof_exit: 0
      stderr: "error: run this command inside a Git worktree\n"
    }
    {
      name: "a failed process listing"
      cwd: $repo.main
      lsof_exit: 1
      stderr: $"error: listing open files failed\n    ($lsof_error)\n"
    }
  ]

  for case in $cases {
    let requests = [(mr 1 "feat/wt" "merged" $tip)]

    let result = (clean $repo --cwd $case.cwd --requests $requests --lsof-exit $case.lsof_exit)

    assert equal $result.exit_code 2 $case.name
    assert equal $result.stdout "" $case.name
    assert equal $result.stderr $case.stderr $case.name
    assert-kept $repo $worktree "feat/wt" $case.name
    assert ($lost in (worktrees $repo)) $case.name
  }
}

# --------------------------------------------------------------------------------------------------
# Worktrees in use
# --------------------------------------------------------------------------------------------------

def "test a worktree in use is kept even when its branch is finished" [] {
  let cases = [
    {
      name: "a process inside it"
      lock: null
      processes: [
        {pid: 4242, command: "vim", files: ["{wt}" "{wt}/README.md"]}
        {pid: 5151, command: "tail", files: ["{wt}-other/app.log"]}
      ]
      lines: ["SKIP {wt}: is in use by running processes" "    4242 vim"]
    }
    {
      name: "a lock in another format"
      lock: "workmux: in use"
      processes: []
      lines: ["SKIP {wt}: is locked: workmux: in use"]
    }
    {
      name: "a lock without a reason"
      lock: ""
      processes: []
      lines: ["SKIP {wt}: is locked without a reason"]
    }
    {
      name: "another live session's lock"
      lock: (claude-lock 1)
      processes: []
      lines: ["SKIP {wt}: is locked by another running session (pid 1)"]
    }
  ]

  for case in ($cases | enumerate) {
    let repo = (make-repo)
    let tip = (git-in $repo.main rev-parse origin/main)
    let worktree = (add-worktree $repo "wt")
    make-dirty $worktree
    if $case.item.lock != null {
      if ($case.item.lock | is-empty) {
        git-in $repo.main worktree lock $worktree
      } else {
        git-in $repo.main worktree lock --reason $case.item.lock $worktree
      }
    }
    let open = (lsof-listing $case.item.processes | str replace --all "{wt}" $worktree)
    let requests = [(mr 1 "feat/wt" "merged" $tip)]

    let result = (clean $repo --requests $requests --open $open)

    let expected = ($case.item.lines | each { str replace "{wt}" $worktree })
    assert equal $result.lines $expected $case.item.name
    assert equal $result.exit_code 1 $case.item.name
    assert-kept $repo $worktree "feat/wt" $case.item.name
  }
}

def "test a lock is released for an exited session or a finished branch of this session" [] {
  let stale = (dead-pid)
  let cases = [
    {
      name: "an exited session's lock on an idle branch"
      pid: $stale
      requests: false
      removed: true
    }
    {
      name: "this session's lock on a finished branch"
      pid: $nu.pid
      requests: true
      removed: true
    }
    {
      name: "this session's lock on an idle branch"
      pid: $nu.pid
      requests: false
      removed: false
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let tip = (git-in $repo.main rev-parse origin/main)
    let worktree = (add-worktree $repo "wt")
    make-idle $worktree
    git-in $repo.main worktree lock --reason (claude-lock $case.pid) $worktree
    let requests = (if $case.requests { [(mr 1 "feat/wt" "merged" $tip)] } else { [] })

    let result = (clean $repo --requests $requests)

    let unlock = [$"git worktree unlock ($worktree)"]
    let expected = (
      if not $case.removed {
        [$"SKIP ($worktree): is locked by this session \(pid ($nu.pid)\)"]
      } else if $case.requests {
        removal $worktree "merge request !1 is merged" --branch "feat/wt" --force --steps $unlock
      } else {
        let reason = "every commit is on a remote, last commit 3 days ago"
        removal $worktree $reason --branch "feat/wt" --steps $unlock
      }
    )
    assert equal $result.lines $expected $case.name
    if $case.removed {
      assert equal $result.exit_code 0 $case.name
      assert-removed $repo $worktree $case.name
    } else {
      assert equal $result.exit_code 1 $case.name
      assert-kept $repo $worktree "feat/wt" $case.name
    }
  }
}

def "test a locked worktree whose directory is gone is pruned only after a released lock" [] {
  let cases = [
    {
      name: "an exited session's lock"
      lock: (claude-lock (dead-pid))
      pruned: true
    }
    {
      name: "this session's lock"
      lock: (claude-lock $nu.pid)
      pruned: true
    }
    {
      name: "a lock in another format"
      lock: "workmux: in use"
      pruned: false
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let worktree = (add-worktree $repo "wt")
    git-in $repo.main worktree lock --reason $case.lock $worktree
    rm --recursive $worktree

    let result = (clean $repo)

    let expected = (
      if $case.pruned {
        [
          $"CLEAN ($worktree): its directory is missing"
          $"DONE ($worktree): git worktree unlock ($worktree)"
          $"DONE ($worktree): git worktree prune"
        ]
      } else {
        [$"SKIP ($worktree): its directory is missing"]
      }
    )
    assert equal $result.lines $expected $case.name
    assert equal $result.exit_code (if $case.pruned { 0 } else { 1 }) $case.name
    assert equal ($worktree in (worktrees $repo)) (not $case.pruned) $case.name
  }
}

# --------------------------------------------------------------------------------------------------
# Requests
# --------------------------------------------------------------------------------------------------

def "test the forge is detected from the origin URL or its SSH host alias" [] {
  let hostnames = {
    "git@work": "github.com"
    "deploy@work": "github.com"
    work: "git.example"
    "github.com-443": "ssh.github.com"
    "github.com-mirror": "git.example"
  }
  let cases = [
    {
      name: "a URL"
      url: "https://github.com/example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "a URL mapped to a mirror by insteadOf"
      url: "https://github.com/example/app.git"
      base: "https://git.example/github/"
      prefix: "https://github.com/"
      extra: ""
      github: true
    }
    {
      name: "a shorthand URL rewritten by insteadOf"
      url: "gh:app.git"
      base: "git@github.com:example/"
      prefix: "gh:"
      extra: ""
      github: true
    }
    {
      name: "several configured URLs"
      url: "https://github.com/example/app.git"
      base: ""
      prefix: ""
      extra: "https://github.com/example/other.git"
      github: true
    }
    {
      name: "an SSH URL"
      url: "ssh://git@github.com:22/example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "an scp-like URL"
      url: "git@github.com:example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "an SSH host alias"
      url: "git@work:example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "an SSH host alias selected by its user"
      url: "ssh://deploy@work/example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "an SSH host alias over port 443"
      url: "git@github.com-443:example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "an alternate SSH host"
      url: "ssh://git@ssh.github.com/example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: true
    }
    {
      name: "an SSH host alias to another host"
      url: "git@github.com-mirror:example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: false
    }
    {
      name: "a URL whose SSH alias would map it to GitHub"
      url: "https://work/example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: false
    }
    {
      name: "a GitLab URL"
      url: "git@gitlab.com:example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: false
    }
    {
      name: "a local path"
      url: "/srv/example/app.git"
      base: ""
      prefix: ""
      extra: ""
      github: false
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let tip = (git-in $repo.main rev-parse origin/main)
    let worktree = (add-worktree $repo "wt")
    git-in $repo.main remote set-url origin $case.url
    if ($case.base | is-not-empty) {
      git-in $repo.main config --global $"url.($case.base).insteadOf" $case.prefix
    }
    if ($case.extra | is-not-empty) {
      git-in $repo.main config --add remote.origin.url $case.extra
    }
    let requests = (
      if $case.github {
        [{number: 7, headRefName: "feat/wt", state: "MERGED", headRefOid: $tip}]
      } else {
        [(mr 3 "feat/wt" "merged" $tip)]
      }
    )
    let lookup = (
      if $case.github {
        [
          pr list
            --repo "example/app"
            --head "feat/wt"
            --state all
            --json "number,state,headRefOid"
        ]
      } else {
        [
          mr list
            --source-branch "feat/wt"
            --all
            --output json
        ]
      }
    )

    let result = (clean $repo --requests $requests --ssh-hostnames $hostnames)

    let evidence = (
      if $case.github { "pull request #7 is merged" } else { "merge request !3 is merged" }
    )
    assert equal $result.lines (removal $worktree $evidence --branch "feat/wt" --force) $case.name
    assert equal $result.exit_code 0 $case.name
    assert-removed $repo $worktree $case.name
    assert equal $result.calls [{args: $lookup}] $case.name
  }
}

def "test a rejected SSH configuration ends the run only when it is resolved" [] {
  let error = "Bad configuration option: usekeychain"
  let cases = [
    {
      name: "an SSH origin"
      url: "git@work:example/app.git"
      base: ""
      prefix: ""
      exit_code: 2
      stdout: ""
      stderr: $"error: resolving git@work through ssh failed\n    ($error)\n"
    }
    {
      name: "a GitHub origin beside a rewritten SSH URL"
      url: "https://github.com/example/app.git"
      base: "git@github.com:"
      prefix: "https://github.com/"
      exit_code: 0
      stdout: "Nothing to clean up.\n"
      stderr: ""
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    git-in $repo.main remote set-url origin $case.url
    if ($case.base | is-not-empty) {
      git-in $repo.main config --global $"url.($case.base).insteadOf" $case.prefix
    }

    let result = (clean $repo --ssh-error $error --ssh-exit 255)

    assert equal $result.exit_code $case.exit_code $case.name
    assert equal $result.stdout $case.stdout $case.name
    assert equal $result.stderr $case.stderr $case.name
  }
}

def "test the worktree of a finished branch is removed with its uncommitted work" [] {
  let cases = [
    {
      name: "a merged merge request"
      requests: {|tip| [(mr 2 "feat/wt" "closed" $tip) (mr 3 "feat/wt" "merged" $tip)] }
      github: false
      evidence: "merge request !3 is merged"
    }
    {
      name: "a closed merge request beside another branch's open one"
      requests: {|tip| [(mr 4 "feat/wt" "closed" $tip) (mr 5 "feat/other" "opened" $tip)] }
      github: false
      evidence: "merge request !4 is closed"
    }
    {
      name: "a merged pull request"
      requests: {|tip| [{number: 7, headRefName: "feat/wt", state: "MERGED", headRefOid: $tip}] }
      github: true
      evidence: "pull request #7 is merged"
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let worktree = (add-worktree $repo "wt")
    let tip = (commit-files $worktree {"feature.txt": "feature\n"} "feat: add feature")
    if $case.github {
      git-in $repo.main remote set-url origin "git@github.com:example/app.git"
    }
    make-dirty $worktree

    let result = (clean $repo --requests (do $case.requests $tip))

    let expected = (removal $worktree $case.evidence --branch "feat/wt" --force)
    assert equal $result.lines $expected $case.name
    assert equal $result.exit_code 0 $case.name
    assert-removed $repo $worktree $case.name
    assert not (has-branch $repo "feat/wt") $case.name
  }
}

def "test a request whose head lacks the branch tip leaves the branch unfinished" [] {
  let cases = [
    {
      name: "a later commit on the branch"
      sha: {|repo| git-in $repo.main rev-parse origin/main }
    }
    {
      name: "a head missing from the repository"
      sha: {|repo| "0123456789abcdef0123456789abcdef01234567" }
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let worktree = (add-worktree $repo "wt")
    commit-files $worktree {"later.txt": "later\n"} "feat: add later work"
    make-dirty $worktree 3day

    let result = (clean $repo --requests [(mr 1 "feat/wt" "merged" (do $case.sha $repo))])

    let problem = "uncommitted work, last touched 3 days ago. Review whether it needs an MR."
    assert equal $result.lines [$"SKIP ($worktree): ($problem)"] $case.name
    assert equal $result.exit_code 1 $case.name
    assert-kept $repo $worktree "feat/wt" $case.name
  }
}

def "test a failed lookup skips the worktree" [] {
  let repo = (make-repo)
  let worktree = (add-worktree $repo "wt")
  make-idle $worktree
  let forge_error = (
    ["    " "  ERROR  " "    " "  No remote matches GITLAB_HOST.  " "  Add a matching remote.  "]
    | str join "\n"
  )

  let result = (clean $repo --forge-error $forge_error)

  assert equal $result.lines [
    $"SKIP ($worktree): looking up its requests failed"
    "    ERROR"
    "    No remote matches GITLAB_HOST."
    "    Add a matching remote."
  ]
  assert equal $result.exit_code 1
  assert-kept $repo $worktree "feat/wt" "lookup failure"
}

def "test an open request keeps its worktree untouched" [] {
  let cases = [
    {
      name: "uncommitted work"
      dirty: true
      requests: {|tip| [(mr 3 "feat/wt" "opened" $tip)] }
    }
    {
      name: "an idle clean worktree"
      dirty: false
      requests: {|tip| [(mr 3 "feat/wt" "opened" $tip)] }
    }
    {
      name: "an open request beside a newer merged one"
      dirty: false
      requests: {|tip| [(mr 3 "feat/wt" "opened" $tip) (mr 4 "feat/wt" "merged" $tip)] }
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let tip = (git-in $repo.main rev-parse origin/main)
    let worktree = (add-worktree $repo "wt")
    if $case.dirty {
      make-dirty $worktree
    }
    make-idle $worktree

    let result = (clean $repo --requests (do $case.requests $tip))

    assert equal $result.lines ["Nothing to clean up."] $case.name
    assert equal $result.exit_code 0 $case.name
    assert-kept $repo $worktree "feat/wt" $case.name
  }
}

# --------------------------------------------------------------------------------------------------
# Unfinished branches and detached worktrees
# --------------------------------------------------------------------------------------------------

def "test uncommitted work keeps an unfinished worktree with its age" [] {
  for file in ["draft.txt" "README.md"] {
    let repo = (make-repo)
    let worktree = (add-worktree $repo "wt")
    let path = ($worktree | path join $file)
    "edited\n" | save --force $path
    set-age $path 3day
    make-idle $worktree

    let result = (clean $repo)

    let problem = "uncommitted work, last touched 3 days ago. Review whether it needs an MR."
    assert equal $result.lines [$"SKIP ($worktree): ($problem)"] $file
    assert equal $result.exit_code 1 $file
    assert-kept $repo $worktree "feat/wt" $file
  }
}

def "test an idle clean worktree is removed and keeps a branch with unpublished commits" [] {
  let review = "last commit 3 days ago, so branch {b} stays. Review whether it needs an MR."
  let cases = [
    {
      name: "a pushed branch"
      branch: "feat/wt"
      commits: 1
      fresh: false
      idle: true
      push: true
      reason: "every commit is on a remote, last commit 3 days ago"
    }
    {
      name: "a backup branch"
      branch: "backup/wt"
      commits: 2
      fresh: false
      idle: true
      push: false
      reason: $"2 unpublished commits, ($review)"
    }
    {
      name: "an agent branch"
      branch: "worktree-agent-wt"
      commits: 1
      fresh: false
      idle: true
      push: false
      reason: $"1 unpublished commit, ($review)"
    }
    {
      name: "a fresh checkout"
      branch: "feat/wt"
      commits: 0
      fresh: false
      idle: false
      push: false
      reason: null
    }
    {
      name: "a fresh commit"
      branch: "feat/wt"
      commits: 1
      fresh: true
      idle: true
      push: true
      reason: null
    }
  ]

  for case in $cases {
    let repo = (make-repo)
    let worktree = (add-worktree $repo "wt" --branch $case.branch)
    let date = (if $case.fresh { git-date 0sec } else { git-date 3day })
    for n in 1..<($case.commits + 1) {
      with-env {GIT_COMMITTER_DATE: $date} {
        commit-files $worktree {$"note-($n).txt": "note\n"} $"docs: add note ($n)"
      }
    }
    if $case.push {
      git-in $worktree push origin $case.branch
    }
    "ignored\n" | save ($worktree | path join "build.log")
    if $case.idle {
      make-idle $worktree
    }

    let result = (clean $repo)

    if $case.reason == null {
      assert equal $result.lines ["Nothing to clean up."] $case.name
      assert-kept $repo $worktree $case.branch $case.name
      continue
    }
    let reason = ($case.reason | str replace "{b}" $case.branch)
    let branch = (if $case.push { $case.branch } else { "" })
    assert equal $result.lines (removal $worktree $reason --branch $branch) $case.name
    assert equal $result.exit_code 0 $case.name
    assert-removed $repo $worktree $case.name
    assert equal (has-branch $repo $case.branch) (not $case.push) $case.name
  }
}

def "test a detached worktree is removed only when idle and a ref holds its HEAD" [] {
  let repo = (make-repo)
  let kept = (commit-detached $repo "kept.txt")
  git-in $repo.main branch keep/local $kept
  let tagged = (commit-detached $repo "tagged.txt")
  git-in $repo.main tag v1 $tagged
  let held = (add-worktree $repo "held" --detach)
  let local = (add-worktree $repo "local" --detach --start $kept)
  let tag = (add-worktree $repo "tag" --detach --start $tagged)
  let fresh = (add-worktree $repo "fresh" --detach)
  let loose = (add-worktree $repo "loose" --detach)
  with-env {GIT_COMMITTER_DATE: (git-date 3day)} {
    commit-files $loose {"loose.txt": "loose\n"} "feat: add loose"
  }
  for worktree in [$held $local $tag $loose] {
    make-idle $worktree
  }

  let result = (clean $repo)

  let held_reason = "detached HEAD on a ref, last commit 3 days ago"
  let loose_problem = "detached HEAD with 1 commit on no ref, last commit 3 days ago"
  let local_problem = "1 unpublished commit, last commit 3 days ago"
  assert equal $result.lines (
    (removal $held $held_reason)
    ++ (removal $local $held_reason)
    ++ [$"SKIP ($loose): ($loose_problem). Review whether it needs an MR."]
    ++ (removal $tag $held_reason)
    ++ [$"SKIP keep/local: ($local_problem). Review whether it needs an MR."]
  )
  assert equal $result.exit_code 1
  for worktree in [$held $local $tag] {
    assert-removed $repo $worktree $worktree
  }
  assert-kept $repo $fresh "" "fresh"
  assert-kept $repo $loose "" "loose"
  assert (has-branch $repo "keep/local")
}

# --------------------------------------------------------------------------------------------------
# Agent memory
# --------------------------------------------------------------------------------------------------

def "test agent memory and plans move into the main checkout without overwriting it" [] {
  let repo = (make-repo)
  let worktree = (add-worktree $repo "wt")
  let plans = ($worktree | path join $PLANS)
  mkdir $plans
  "tracked\n" | save ($plans | path join "tracked.md")
  git-in $worktree add --force ($plans | path join "tracked.md")
  git-in $worktree commit -m "docs: track a plan"
  let tip = (git-in $worktree rev-parse HEAD)
  "plan\n" | save ($plans | path join "notes.md")
  let main_memory = ($repo.main | path join $MEMORY)
  let memory = ($worktree | path join $MEMORY)
  mkdir ($main_memory | path join "tester") ($memory | path join "tester")
  "- [A](a.md) - a\n- [C](c.md) - c" | save ($main_memory | path join "MEMORY.md")
  "- [A](a.md) - a\n\n- [B](b.md) - b\n" | save ($memory | path join "MEMORY.md")
  "same\n" | save ($main_memory | path join "tester/same.md")
  "same\n" | save ($memory | path join "tester/same.md")
  "new\n" | save ($memory | path join "tester/.notes.md")

  let result = (clean $repo --requests [(mr 1 "feat/wt" "merged" $tip)])

  let steps = [
    $"copy ($PLANS)/notes.md to the main checkout"
    $"append 1 new line to ($MEMORY)/MEMORY.md in the main checkout"
    $"copy ($MEMORY)/tester/.notes.md to the main checkout"
  ]
  let expected = (
    removal $worktree "merge request !1 is merged" --branch "feat/wt" --force --steps $steps
  )
  assert equal $result.lines $expected
  assert equal $result.exit_code 0
  assert equal (open --raw ($main_memory | path join "MEMORY.md")) (
    "- [A](a.md) - a\n- [C](c.md) - c\n- [B](b.md) - b\n"
  )
  assert equal (open --raw ($main_memory | path join "tester/.notes.md")) "new\n"
  assert equal (open --raw ($main_memory | path join "tester/same.md")) "same\n"
  assert equal (open --raw ($repo.main | path join $"($PLANS)/notes.md")) "plan\n"
  assert not ($repo.main | path join $"($PLANS)/tracked.md" | path exists)
}

# --------------------------------------------------------------------------------------------------
# Repository sweeps
# --------------------------------------------------------------------------------------------------

def "test a dry run reports the plan and changes nothing" [] {
  let repo = (make-repo)
  let tip = (git-in $repo.main rev-parse origin/main)
  let worktree = (add-worktree $repo "wt")
  let pid = (dead-pid)
  git-in $repo.main worktree lock --reason (claude-lock $pid) $worktree
  mkdir ($worktree | path join $MEMORY)
  "new\n" | save ($worktree | path join $"($MEMORY)/notes.md")
  let lost = (add-worktree $repo "lost")
  rm --recursive $lost
  git-in $repo.main branch feat/merged origin/main
  let requests = [
    (mr 1 "feat/wt" "merged" $tip)
    (mr 2 "feat/merged" "merged" $tip)
    (mr 3 "feat/lost" "merged" $tip)
  ]

  let result = (clean $repo --dry-run --requests $requests)

  let plan = [
    $"copy ($MEMORY)/notes.md to the main checkout"
    $"git worktree unlock ($worktree)"
    $"git worktree remove --force ($worktree)"
    "git branch -D -- feat/wt"
  ]
  assert equal $result.lines (
    [$"CLEAN ($worktree): merge request !1 is merged"]
    ++ ($plan | each {|step| $"PLAN ($worktree): ($step)" })
    ++ [
      "CLEAN feat/lost: merge request !3 is merged"
      "PLAN feat/lost: git branch -D -- feat/lost"
      "CLEAN feat/merged: merge request !2 is merged"
      "PLAN feat/merged: git branch -D -- feat/merged"
    ]
  )
  assert equal $result.exit_code 0
  assert-kept $repo $worktree "feat/wt" "dry run"
  assert ($lost in (worktrees $repo))
  assert str contains (git-in $repo.main worktree list --porcelain) (claude-lock $pid)
  assert not ($repo.main | path join $"($MEMORY)/notes.md" | path exists)
  assert (has-branch $repo "feat/merged")
}

def "test a sweep cleans finished branches and worktrees across the repository" [] {
  let repo = (make-repo)
  let tip = (git-in $repo.main rev-parse origin/main)
  let done = (add-worktree $repo "done")
  make-dirty $done
  let backup = (add-worktree $repo "backup" --branch "backup/old")
  with-env {GIT_COMMITTER_DATE: (git-date 3day)} {
    commit-files $backup {"old.txt": "old\n"} "chore: keep old work"
  }
  make-idle $backup
  let here = (add-worktree $repo "here")
  let subdir = ($here | path join "docs")
  mkdir $subdir
  let lost = (add-worktree $repo "lost")
  rm --recursive $lost

  let stuck = (commit-detached $repo "stuck.txt")
  git-in $repo.main branch feat/stuck $stuck
  make-gone $repo "feat/stuck"
  git-in $repo.main branch feat/fresh-gone (commit-detached $repo "fresh.txt" --age 2hr)
  make-gone $repo "feat/fresh-gone"
  for branch in ["feat/merged" "feat/open" "feat/plain"] {
    git-in $repo.main branch $branch origin/main
  }
  git-in $repo.main branch worktree-agent-old (commit-detached $repo "old-agent.txt")
  git-in $repo.main branch worktree-agent-new (commit-detached $repo "new-agent.txt" --age 2hr)
  git-in $repo.main branch feat/pushed (commit-detached $repo "pushed.txt" --age 2hr)
  git-in $repo.main push origin feat/pushed
  let requests = (
    ["main" "feat/done" "feat/here" "feat/lost" "feat/merged"]
    | enumerate
    | each {|row| mr ($row.index + 1) $row.item "merged" $tip }
    | append (mr 9 "feat/open" "opened" $tip)
  )

  let result = (clean $repo --cwd $subdir --requests $requests)

  let unpublished = "1 unpublished commit, last commit 3 days ago"
  let review = "Review whether it needs an MR."
  let expected = [
    ...(removal $backup $"($unpublished), so branch backup/old stays. ($review)")
    ...(removal $done "merge request !2 is merged" --branch "feat/done" --force)
    $"SKIP feat/fresh-gone: its upstream is gone, 1 unpublished commit, last commit 2 hours ago. ($review)"
    "CLEAN feat/lost: merge request !4 is merged"
    "DONE feat/lost: git branch -D -- feat/lost"
    "CLEAN feat/merged: merge request !5 is merged"
    "DONE feat/merged: git branch -D -- feat/merged"
    "CLEAN feat/plain: every commit is on a remote, last commit 3 days ago"
    "DONE feat/plain: git branch -D -- feat/plain"
    $"SKIP feat/stuck: its upstream is gone, ($unpublished). ($review)"
    $"SKIP worktree-agent-old: ($unpublished). ($review)"
  ]
  assert equal $result.lines $expected
  assert equal $result.exit_code 1
  assert-removed $repo $done "done"
  assert-removed $repo $backup "backup"
  assert ($lost not-in (worktrees $repo))
  assert-kept $repo $here "feat/here" "current worktree"
  let kept = [
    "backup/old"
    "feat/fresh-gone"
    "feat/open"
    "feat/pushed"
    "feat/stuck"
    "main"
    "worktree-agent-new"
    "worktree-agent-old"
  ]
  for branch in $kept {
    assert (has-branch $repo $branch) $branch
  }
  for branch in ["feat/done" "feat/lost" "feat/merged" "feat/plain"] {
    assert not (has-branch $repo $branch) $branch
  }
}
