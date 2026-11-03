#!/usr/bin/env nu

# ==================================================================================================
# File Formatter Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join file-formatter.nu)
const REPORT_PREFIX = "The pre-commit hooks reported problems in the edited files."

# A gate in which each hook record runs its `entry` on files matching its `files`.
def gate [...hooks: record]: nothing -> string {
  let hooks = ($hooks | each {|hook| $hook | merge {name: $hook.id, language: system} })
  {repos: [{repo: local, hooks: $hooks}]} | to yaml
}

source $SCRIPT

# Creates a repository with gate `config` and a Git hook unless `--no-hook` or `--no-config`.
def make-repo [dir: string, config: string, --no-hook, --no-config]: nothing -> string {
  mkdir $dir
  ^git -C $dir init --quiet
  if not $no_config {
    $config | save --force ($dir | path join .pre-commit-config.yaml)
  }
  if not $no_hook {
    touch ($dir | path join .git hooks pre-commit)
  }
  $dir
}

# Writes the hook script that checks the marker the `.envrc` exports and logs each run.
def write-marker-script [repo: string]: nothing -> nothing {
  (
    r#'
    #!/bin/sh
    echo run >> marker.log
    test "$GATE_MARKER" = loaded
    '#
    | str dedent
  ) | save --force ($repo | path join marker.sh)
}

# Writes the `.envrc` that exports the marker.
def write-marker-envrc [repo: string]: nothing -> nothing {
  "export GATE_MARKER=loaded\n" | save ($repo | path join .envrc)
}

# Allows the `.envrc` in `dir`.
def allow-envrc [dir: string]: nothing -> nothing {
  let allowed = (
    with-env { XDG_DATA_HOME: ($env.TMPDIR | path join data) } { ^direnv allow $dir | complete }
  )
  assert equal $allowed.exit_code 0 $allowed.stderr
}

def run-formatter [cwd: string, ...paths: string]: nothing -> record {
  let run = (
    with-env {
      XDG_CACHE_HOME: ($env.TMPDIR | path join cache)
      XDG_DATA_HOME: ($env.TMPDIR | path join data)
    } {
      cd $cwd
      ^$nu.current-exe --no-config-file $SCRIPT ...$paths | complete
    }
  )
  {
    run: $run
    report: ($run.stdout | str trim)
  }
}

def "test failed hook blocks keep failures and drop formatter rewrites" [] {
  let long = (
    ["a...Failed" "- exit code: 1"]
    | append (1..25 | each {|n| $"line ($n)" })
    | str join "\n"
  )
  let truncated = (
    ["a...Failed" "- exit code: 1"]
    | append (1..18 | each {|n| $"line ($n)" })
    | str join "\n"
  )
  let cases = [
    {
      name: "no output"
      output: ""
      reports: [""]
    }
    {
      name: "formatter only"
      output: (
        r#'
        nixfmt...Failed
        - hook id: nixfmt
        - files were modified by this hook
        '#
        | str dedent
      )
      reports: []
    }
    {
      name: "failed and formatting hooks"
      output: (
        r#'
        a...Failed
        - exit code: 1
        x
        b...Failed
        - files were modified by this hook
        c...Failed
        - exit code: 2
        y
        '#
        | str dedent
      )
      reports: [
        (
          r#'
          a...Failed
          - exit code: 1
          x
          '#
          | str dedent
        )
        (
          r#'
          c...Failed
          - exit code: 2
          y
          '#
          | str dedent
        )
      ]
    }
    {
      name: "long block truncates"
      output: $long
      reports: [$truncated]
    }
  ]

  for case in $cases {
    assert equal (failed-blocks $case.output) $case.reports $case.name
  }
}

def "test a fixer hook that rewrites a file is not reported" [] {
  let config = (gate {id: fixer, entry: "bash fix.sh", files: '\.txt$'})
  let repo = (make-repo ($env.TMPDIR | path join repo-fixer) $config)
  (
    r#'
    #!/bin/sh
    changed=0
    for f in "$@"; do
      if [ -n "$(tail -c 1 "$f")" ]; then
        printf '\n' >> "$f"
        changed=1
      fi
    done
    exit $changed
    '#
    | str dedent
  ) | save --force ($repo | path join fix.sh)
  let file = ($repo | path join notes.txt)
  "content" | save $file

  let result = (run-formatter $repo $file)

  assert equal (open --raw $file) "content\n"
  assert equal $result.run.exit_code 0
  assert equal $result.report ""
}

def "test only the failed hooks are rerun after a fixer rewrites the file" [] {
  let config = (
    gate
      {id: check, entry: "bash check.sh", files: '\.txt$'}
      {id: fix, entry: "bash fix.sh", files: '\.txt$'}
      {id: lint, entry: "bash lint.sh", files: '\.txt$'}
  )
  let repo = (make-repo ($env.TMPDIR | path join repo-rerun) $config)
  (
    r#'
    #!/bin/sh
    echo run >> check.log
    exit 0
    '#
    | str dedent
  ) | save --force ($repo | path join check.sh)
  (
    r#'
    #!/bin/sh
    echo run >> fix.log
    if [ -n "$(tail -c 1 "$1")" ]; then
      printf '\n' >> "$1"
      exit 1
    fi
    exit 0
    '#
    | str dedent
  ) | save --force ($repo | path join fix.sh)
  (
    r#'
    #!/bin/sh
    echo run >> lint.log
    echo lint-bad
    exit 1
    '#
    | str dedent
  ) | save --force ($repo | path join lint.sh)
  let file = ($repo | path join notes.txt)
  "content" | save $file

  let result = (run-formatter $repo $file)

  assert equal (open --raw $file) "content\n"
  assert equal $result.run.exit_code 1
  assert ($result.report | str contains "lint-bad")
  assert not ($result.report | str contains "- hook id: fix")
  assert equal (open ($repo | path join check.log) | lines | length) 1
  assert equal (open ($repo | path join fix.log) | lines | length) 2
  assert equal (open ($repo | path join lint.log) | lines | length) 2
}

def "test a failing hook is reported" [] {
  let repo = (
    make-repo ($env.TMPDIR | path join repo-lint) (gate
      {id: lint, entry: "bash lint.sh", files: '\.txt$'}
      {id: ok, entry: "true", files: '\.txt$'}
    )
  )
  (
    r#'
    #!/bin/sh
    echo run >> lint.log
    echo lint-bad-pattern
    exit 1
    '#
    | str dedent
  ) | save --force ($repo | path join lint.sh)
  let file = ($repo | path join notes.txt)
  "content\n" | save $file

  let result = (run-formatter $repo $file)

  assert equal $result.run.exit_code 1
  assert ($result.report | str starts-with $REPORT_PREFIX)
  assert ($result.report | str contains "- exit code: 1")
  assert ($result.report | str contains "lint-bad-pattern")
  assert not ($result.report | str contains "Passed")
  assert equal (open ($repo | path join lint.log) | lines | length) 1
}

def "test repositories without an installed hook or a gate config are skipped" [] {
  let config = (gate {id: nixfmt, entry: "nixfmt", files: '\.nix$'})
  let cases = [
    {
      name: "no installed hook"
      repo: (make-repo ($env.TMPDIR | path join repo-without-hook) $config --no-hook)
    }
    {
      name: "no gate config"
      repo: (make-repo ($env.TMPDIR | path join repo-without-config) $config --no-config)
    }
  ]

  for case in $cases {
    let file = ($case.repo | path join bad.nix)
    "{a=1;}" | save $file

    let result = (run-formatter $case.repo $file)

    assert equal $result.run.exit_code 0 $case.name
    assert equal $result.report "" $case.name
    assert equal (open --raw $file) "{a=1;}" $case.name
  }
}

def "test a broken pre-commit config is reported" [] {
  let repo = (make-repo ($env.TMPDIR | path join repo-broken) "repos: [\n")
  let file = ($repo | path join notes.txt)
  "content\n" | save $file

  let result = (run-formatter $repo $file)

  assert equal $result.run.exit_code 1
  assert ($result.report | str starts-with $REPORT_PREFIX)
  assert ($result.report | str contains "Failed to parse")
}

def "test paths from two repositories, an outside path and a deleted path" [] {
  let base = ($env.TMPDIR | path join repo-pair)
  let config = (gate {id: nixfmt, entry: "nixfmt", files: '\.nix$'})
  let first = (make-repo ($base | path join first) $config)
  let second = (make-repo ($base | path join second) $config)
  let sub = ($first | path join sub)
  mkdir $sub
  let a = ($first | path join a.nix)
  let b = ($second | path join b.nix)
  let outside = ($base | path join outside c.nix)
  let deleted = ($first | path join deleted.nix)
  let dash = "-s.nix"
  let dash_file = ($sub | path join $dash)
  mkdir ($base | path join outside)
  "{a=1;}" | save $a
  "{b=2;}" | save $b
  "{c=3;}" | save $outside
  "{s=4;}" | save $dash_file

  let result = (run-formatter $sub ../a.nix $dash $b $outside $deleted)

  assert equal (open --raw $a) "{ a = 1; }\n"
  assert equal (open --raw $b) "{ b = 2; }\n"
  assert equal (open --raw $dash_file) "{ s = 4; }\n"
  assert equal (open --raw $outside) "{c=3;}"
  assert equal $result.run.exit_code 0
  assert equal $result.report ""
}

def "test an allowed, blocked, or absent envrc decides the gate environment" [] {
  let config = (gate {id: marker, entry: "bash marker.sh", files: '\.txt$'})
  let allowed = (make-repo ($env.TMPDIR | path join repo-envrc-allowed) $config)
  let blocked = (make-repo ($env.TMPDIR | path join repo-envrc-blocked) $config)
  let none = (make-repo ($env.TMPDIR | path join repo-envrc-none) $config)
  for repo in [$allowed $blocked $none] {
    write-marker-script $repo
  }
  write-marker-envrc $allowed
  write-marker-envrc $blocked
  allow-envrc $allowed

  let cases = [
    {name: "allowed", repo: $allowed, exit_code: 0}
    {name: "blocked", repo: $blocked, exit_code: 1}
    {name: "absent", repo: $none, exit_code: 1}
  ]
  for case in $cases {
    let file = ($case.repo | path join notes.txt)
    "content\n" | save $file

    let result = (run-formatter $case.repo $file)

    assert equal $result.run.exit_code $case.exit_code $case.name
    assert equal (open ($case.repo | path join marker.log) | lines | length) 1 $case.name
    if $case.exit_code == 0 {
      assert equal $result.report "" $case.name
    } else {
      assert ($result.report | str contains "- exit code: 1") $case.name
    }
  }
}

def "test a caller direnv diff that hides prek still runs the gate" [] {
  let prek_dir = (which prek | get 0.path | path dirname)
  let caller = ($env.TMPDIR | path join caller)
  mkdir $caller
  $'export PATH="($prek_dir):$PATH"' | save ($caller | path join .envrc)
  allow-envrc $caller

  let generated = (
    with-env {
      DIRENV_DIFF: null
      DIRENV_DIR: null
      DIRENV_FILE: null
      DIRENV_WATCHES: null
      PATH: ($env.PATH | where $it != $prek_dir | str join ":")
      XDG_DATA_HOME: ($env.TMPDIR | path join data)
    } {
      ^direnv exec $caller $nu.current-exe --no-config-file -c 'print $env.DIRENV_DIFF' | complete
    }
  )
  assert equal $generated.exit_code 0 $generated.stderr
  let diff = ($generated.stdout | str trim)
  assert ($diff | is-not-empty)

  let config = (gate {id: marker, entry: "bash marker.sh", files: '\.txt$'})
  let repo = (make-repo ($env.TMPDIR | path join repo-envrc-diff) $config)
  write-marker-envrc $repo
  write-marker-script $repo
  let file = ($repo | path join notes.txt)
  "content\n" | save $file
  allow-envrc $repo

  let result = (with-env { DIRENV_DIFF: $diff } { run-formatter $env.TMPDIR $file })

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.report ""
}
