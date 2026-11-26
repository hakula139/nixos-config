#!/usr/bin/env nu

# ==================================================================================================
# tmux Task Name Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "task-name.nu")

def invoke [
  name: string
  --env-vars: record = {}
  --inspect: string = ""
  --inspect-fail
  --after: string = ""
]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "calls.jsonl")

  let base_env = {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS | str join ":")
    STUB_LOG: $log
    STUB_INSPECT: $inspect
    STUB_INSPECT_FAIL: (if $inspect_fail { "1" } else { "0" })
    STUB_AFTER: $after
    TMUX: "/tmp/tmux-1000/default,123,0"
    TMUX_PANE: "%0"
  }
  let run = with-env ($base_env | merge $env_vars) {
    run-script $SCRIPT $name
  }

  let calls = if ($log | path exists) {
    open $log | from json --objects | get args
  } else {
    []
  }
  {
    run: $run
    calls: $calls
  }
}

def pane-info [
  --session-id: string = "$0"
  --session-name: string = "0"
  --windows: int = 1
  --window-id: string = "@0"
  --window-name: string = "zsh"
  --auto-rename: int = 1
  --panes: int = 1
  --token: string = ""
  --pane: string = "%0"
]: nothing -> string {
  [
    $"($pane)|($session_id)|($windows)|($window_id)|($panes)|($auto_rename)|($token)"
    $session_name
    $window_name
  ]
  | str join "\n"
}

def assert-ok [result: record, stdout: string] {
  assert equal $result.run {
    stdout: $"($stdout)\n"
    stderr: ""
    exit_code: 0
  }
}

def "test numeric single-window session renames session" [] {
  let result = (
    invoke "my-task"
      --inspect (pane-info)
      --after "my-task"
  )

  assert-ok $result "Renamed session $0 to 'my-task'."
  assert equal ($result.calls | get 1) ["rename-session" "-t" "$0" "my-task"]
}

def "test named session with auto-named window renames window" [] {
  let result = (
    invoke "my-task"
      --inspect (pane-info --session-name "nixos-config")
      --after "my-task"
  )

  assert-ok $result "Renamed window @0 to 'my-task'."
  assert equal ($result.calls | get 1) ["rename-window" "-t" "@0" "my-task"]
}

def "test multi-window numeric session with auto-named window renames window" [] {
  let info = (
    pane-info
      --windows 2
      --window-id "@3"
  )
  let result = (
    invoke "my-task"
      --inspect $info
      --after "my-task"
  )

  assert-ok $result "Renamed window @3 to 'my-task'."
  assert equal ($result.calls | get 1) ["rename-window" "-t" "@3" "my-task"]
}

def "test manually named window skips rename" [] {
  let info = (
    pane-info
      --session-name "nixos-config"
      --window-name "existing|name"
      --auto-rename 0
  )
  let result = (invoke "my-task" --inspect $info)

  assert-ok $result "Skipped: the window already has the name 'existing|name'."
  assert equal ($result.calls | length) 1
}

def "test names with pipes parse cleanly" [] {
  let info = (
    pane-info
      --session-name "proj|a"
      --window-name "win|b"
  )
  let result = (
    invoke "my-task"
      --inspect $info
      --after "my-task"
  )

  assert-ok $result "Renamed window @0 to 'my-task'."
  assert equal ($result.calls | get 1) ["rename-window" "-t" "@0" "my-task"]
}

def "test multi-pane window skips rename" [] {
  let result = (invoke "my-task" --inspect (pane-info --panes 2))

  assert-ok $result "Skipped: its window has 2 panes."
  assert equal ($result.calls | length) 1
}

def "test workmux window skips rename" [] {
  let result = (invoke "my-task" --inspect (pane-info --token "wm-123"))

  assert-ok $result "Skipped: Workmux manages its window."
  assert equal ($result.calls | length) 1
}

def "test outside tmux skips without calling tmux" [] {
  let env_vars = {
    TMUX: ""
    TMUX_PANE: ""
  }
  let result = (invoke "my-task" --env-vars $env_vars)

  assert-ok $result "Skipped: not running inside a tmux pane."
  assert equal $result.calls []
}

def "test unknown pane skips rename" [] {
  let result = (invoke "my-task" --inspect-fail)

  assert-ok $result "Skipped: cannot inspect pane %0."
  assert equal ($result.calls | length) 1
}

def "test mismatched rename raises error" [] {
  let result = (
    invoke "my-task"
      --inspect (pane-info --session-name "nixos-config")
      --after "other-name"
  )

  assert not equal $result.run.exit_code 0
  let expected = "window @0 is named 'other-name' after renaming to 'my-task'"
  assert str contains $result.run.stderr $expected
}
