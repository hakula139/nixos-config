#!/usr/bin/env nu

# ==================================================================================================
# Worktree Remove Hook Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "worktree-remove.nu")

def invoke [payload: record, vars: record]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "calls.jsonl")
  let run = with-env (
    {
      PATH: ($env.PATH | prepend $env.NU_TEST_STUBS | str join ":")
      STUB_LOG: $log
    }
    | merge $vars
  ) {
    $payload
    | to json
    | run-script $SCRIPT
  }

  let calls = if ($log | path exists) {
    open $log | from json --objects
  } else {
    []
  }
  {
    run: $run
    calls: $calls
  }
}

def "test remove deletes through workmux and fails while the directory remains" [] {
  let root = (mktemp --directory)
  let worktree = ($root | path join "app__worktrees/demo")

  let cases = [
    {
      label: "removed"
      present: true
      leaves: false
      exit_code: 0
      calls: [
        {
          cwd: $worktree
          args: ["remove" "--force" "demo"]
        }
      ]
    }
    {
      label: "deferred"
      present: true
      leaves: true
      exit_code: 1
      calls: [
        {
          cwd: $worktree
          args: ["remove" "--force" "demo"]
        }
      ]
    }
    {
      label: "missing"
      present: false
      leaves: false
      exit_code: 0
      calls: []
    }
  ]

  for case in $cases {
    rm --recursive --force $worktree
    if $case.present {
      mkdir $worktree
    }

    let result = (
      invoke {worktree_path: $worktree} {
        STUB_REMOVE_PATH: $worktree
        STUB_REMOVE_LEAVES: (if $case.leaves { "1" } else { "" })
      }
    )

    assert equal $result.run.exit_code $case.exit_code $"($case.label): ($result.run.stderr)"
    assert equal ($worktree | path exists) ($case.present and $case.leaves) $case.label
    assert equal $result.calls $case.calls $case.label
  }
}
