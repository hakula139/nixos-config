#!/usr/bin/env nu

# ==================================================================================================
# tmux Wrapper Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join wrapper.sh)
const STUBS = {
  direnv: ($SCRIPT_DIR | path join direnv.stub.nu)
  tmux: ($SCRIPT_DIR | path join tmux.stub.nu)
}

const SERVER_PATH = "/server/bin"
const REFUSAL = "none is started inside a Nix shell"

# Runs the wrapper over `argv` with stubbed tmux and direnv in an environment holding only the
# caller's PATH plus `env_vars`. `calls` lists the stub invocations in order.
def wrap [argv: list<string>, env_vars: record = {}]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join calls.jsonl)
  let script = ($dir | path join wrapper.sh)

  let stubs = $STUBS | items {|name, source|
    let stub = ($dir | path join $name)
    $"#!($nu.current-exe) --no-config-file\n" + (open --raw $source) | save $stub
    ^chmod +x $stub
    {name: $name, path: $stub}
  } | transpose --header-row --as-record

  open --raw $SCRIPT
  | str replace --all "@direnv@" $"'($stubs.direnv)'"
  | str replace --all "@tmux@" $"'($stubs.tmux)'"
  | save $script

  let assignments = ({STUB_LOG: $log} | merge $env_vars | items {|name, value| $"($name)=($value)" })
  let run = (
    ^env -u DIRENV_DIFF -u IN_NIX_SHELL -u NIX_BUILD_TOP ...$assignments bash $script ...$argv
    | complete
  )

  let calls = if ($log | path exists) {
    open --raw $log | lines | each { from json }
  } else {
    []
  }
  $run | insert calls $calls
}

def caller-path []: nothing -> string {
  [$env.PATH] | flatten | str join (char esep)
}

def "test outside a dev shell tmux runs unchanged" [] {
  let run = (wrap [new-session -A -s work])

  assert equal $run.exit_code 0 $run.stderr
  assert equal $run.calls [{tool: tmux, args: [new-session -A -s work], path: (caller-path)}]
}

def "test a direnv shell is reverted before tmux runs" [] {
  let run = (wrap [new-window] {DIRENV_DIFF: diff, IN_NIX_SHELL: impure})

  assert equal $run.exit_code 0 $run.stderr
  assert equal ($run.calls | get tool) [direnv tmux]
  assert equal ($run.calls.0.args | take 2) [exec /]
  assert equal $run.calls.1.args [new-window]
}

def "test a Nix shell client borrows the running server PATH" [] {
  let run = (wrap [new-window "cargo run"] {IN_NIX_SHELL: impure, STUB_SERVER_PATH: $SERVER_PATH})

  assert equal $run.exit_code 0 $run.stderr
  assert equal $run.calls [
    {tool: tmux, args: [-N show-environment -g PATH], path: (caller-path)}
    {tool: tmux, args: [-N new-window "cargo run"], path: $SERVER_PATH}
  ]
}

def "test a Nix shell nested in a direnv shell is still caught" [] {
  let env_vars = {
    DIRENV_DIFF: diff
    IN_NIX_SHELL: impure
    NIX_BUILD_TOP: /tmp/nix-shell
    STUB_SERVER_PATH: $SERVER_PATH
  }
  let run = (wrap [split-window] $env_vars)

  assert equal $run.exit_code 0 $run.stderr
  assert equal ($run.calls | get tool) [direnv tmux tmux]
  assert equal ($run.calls | last) {tool: tmux, args: [-N split-window], path: $SERVER_PATH}
}

def "test every socket flag reaches the server probe" [] {
  let argv = [-S /tmp/sock -L name new-window]
  let run = (wrap $argv {NIX_BUILD_TOP: /tmp/nix-shell, STUB_SERVER_PATH: $SERVER_PATH})

  assert equal $run.exit_code 0 $run.stderr
  assert equal ($run.calls | get args) [
    [-S /tmp/sock -L name -N show-environment -g PATH]
    [-N ...$argv]
  ]
}

def "test the tmux exit status passes through" [] {
  let cases = [
    {}
    {DIRENV_DIFF: diff}
    {IN_NIX_SHELL: impure, STUB_SERVER_PATH: $SERVER_PATH}
    {IN_NIX_SHELL: impure}
  ]

  for case in $cases {
    let run = (wrap [has-session -t work] ($case | insert STUB_STATUS "3"))
    assert equal $run.exit_code 3 $"env: ($case | to nuon)"
  }
}

def "test only server-starting commands are refused inside a Nix shell" [] {
  let cases = [
    [argv client];
    [[] null]
    [[new-session -s work] null]
    [[-L name new] null]
    [[-f /dev/null start-server] null]
    [[start] null]
    [[new-window] [-N new-window]]
    [[has-session] [-N has-session]]
    [[kill-server] [-N kill-server]]
    [[-V] [-V]]
  ]

  for case in $cases {
    let run = (wrap $case.argv {IN_NIX_SHELL: impure})
    let context = $"argv: ($case.argv | to nuon)"
    let clients = ($run.calls | where {|call| "show-environment" not-in $call.args } | get args)

    if $case.client == null {
      assert equal $run.exit_code 1 $context
      assert str contains $run.stderr $REFUSAL $context
      assert equal $clients [] $context
    } else {
      assert equal $run.exit_code 0 $context
      assert not ($run.stderr | str contains $REFUSAL) $context
      assert equal $clients [$case.client] $context
    }
  }
}
