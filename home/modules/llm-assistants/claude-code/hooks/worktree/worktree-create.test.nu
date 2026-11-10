#!/usr/bin/env nu

# ==================================================================================================
# Worktree Create Hook Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "worktree-create.nu")

# Creates a repository at `root/app`, optionally with a remote whose default branch is set.
def setup-repo [root: string, --with-origin]: nothing -> record {
  let app = ($root | path join "app")
  mkdir $app
  (
    ^git
      -C $app
      init
        --quiet
        --initial-branch main
  )
  ^git -C $app config user.email "test@example.com"
  ^git -C $app config user.name "Test"
  "base" | save ($app | path join "f.txt")
  (
    ^git
      -C $app
      add --all
  )
  (
    ^git
      -C $app
      commit
        --quiet
        --message "base"
  )
  if $with_origin {
    let remote = ($root | path join "remote")
    mkdir $remote
    (
      ^git
        -C $remote
        init
          --quiet
          --bare
          --initial-branch main
    )
    ^git -C $app remote add origin $remote
    (
      ^git
        -C $app
        push origin main
          --quiet
          --set-upstream
    )
    ^git -C $app remote set-head origin main
  }
  {root: $root, app: $app}
}

def git-rev [repo: string, ref: string]: nothing -> string {
  ^git -C $repo rev-parse $ref | str trim
}

def invoke [payload: record, vars: record]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "calls.jsonl")
  let run = with-env (
    {
      PATH: (($env.PATH | prepend $env.NU_TEST_STUBS) | str join ":")
      STUB_LOG: $log
    }
    | merge $vars
  ) {
    (
      $payload
      | to json
      | ^$nu.current-exe --no-config-file
        $SCRIPT
      | complete
    )
  }

  {run: $run, calls: (if ($log | path exists) { open $log | from json --objects } else { [] })}
}

def "test create provisions or reuses a worktree" [] {
  let repo = (setup-repo (mktemp --directory) --with-origin)
  let remote_less = (setup-repo (mktemp --directory))
  let created = ($repo.root | path join "app__worktrees/demo")
  let other = ($repo.root | path join "app__worktrees/other-demo")
  let fallback = (git-rev $remote_less.app "HEAD")

  let cases = [
    {
      label: "origin/HEAD"
      cwd: $repo.app
      existing: ""
      stdout: $created
      calls: [
        {cwd: $repo.app, args: ["path" "demo"]}
        {
          cwd: $repo.app
          args: [
            "add"
            "worktree-demo"
            "--base"
            "origin/main"
            "--name"
            "demo"
            "--no-hooks"
            "--headless"
            "--json"
          ]
        }
      ]
    }
    {
      label: "no origin/HEAD"
      cwd: $remote_less.app
      existing: ""
      stdout: $created
      calls: [
        {cwd: $remote_less.app, args: ["path" "demo"]}
        {
          cwd: $remote_less.app
          args: [
            "add"
            "worktree-demo"
            "--base"
            $fallback
            "--name"
            "demo"
            "--no-hooks"
            "--headless"
            "--json"
          ]
        }
      ]
    }
    {
      label: "reuse"
      cwd: $repo.app
      existing: $created
      stdout: $created
      calls: [{cwd: $repo.app, args: ["path" "demo"]}]
    }
    {
      label: "different basename"
      cwd: $repo.app
      existing: $other
      stdout: $created
      calls: [
        {cwd: $repo.app, args: ["path" "demo"]}
        {
          cwd: $repo.app
          args: [
            "add"
            "worktree-demo"
            "--base"
            "origin/main"
            "--name"
            "demo"
            "--no-hooks"
            "--headless"
            "--json"
          ]
        }
      ]
    }
  ]

  for case in $cases {
    let result = (
      invoke {name: "demo", cwd: $case.cwd} {
        STUB_EXISTING_PATH: $case.existing
        STUB_ADD_PATH: $created
      }
    )

    assert equal $result.run.exit_code 0 $case.label
    assert equal $result.run.stdout $"($case.stdout)\n" $case.label
    assert equal $result.calls $case.calls $case.label
  }
}
