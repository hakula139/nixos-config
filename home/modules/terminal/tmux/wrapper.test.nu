#!/usr/bin/env nu

# ==================================================================================================
# tmux Wrapper Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join wrapper.sh)

const SERVER_PATH = "/server/bin"
const REFUSAL = "none is started inside a Nix shell"

# Runs the wrapper over `argv` with stubbed tmux and direnv in an environment holding only the
# caller's PATH plus `env_vars`, and asserts it exits with `status`. `calls` lists the stub
# invocations in order, and `script` is the wrapper path direnv receives as the command to rerun.
def wrap [argv: list<string>, env_vars: record = {}, --status: int = 0]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join calls.jsonl)
  let script = ($dir | path join wrapper.sh)

  open --raw $SCRIPT
  | str replace --all "@direnv@" $"'($env.NU_TEST_STUBS | path join direnv)'"
  | str replace --all "@tmux@" $"'($env.NU_TEST_STUBS | path join tmux)'"
  | save $script

  let assignments = ({STUB_LOG: $log} | merge $env_vars | items {|name, value| $"($name)=($value)" })
  let run = (
    ^env -u DIRENV_DIFF -u IN_NIX_SHELL -u NIX_BUILD_TOP ...$assignments bash $script ...$argv
    | complete
  )
  let context = $"argv ($argv | to nuon), env ($env_vars | to nuon): ($run.stderr)"
  assert equal $run.exit_code $status $context

  let calls = if ($log | path exists) { open $log | from json --objects } else { [] }
  $run | insert calls $calls | insert script $script
}

def caller-path []: nothing -> string {
  [$env.PATH] | flatten | str join ":"
}

def "test outside a dev shell tmux runs unchanged" [] {
  let run = (wrap [new-session -A -s work])

  assert equal $run.calls [{tool: tmux, args: [new-session -A -s work], path: (caller-path)}]
}

def "test a direnv shell is reverted before tmux runs" [] {
  let run = (wrap [new-window] {DIRENV_DIFF: diff, IN_NIX_SHELL: impure})

  assert equal $run.calls [
    {tool: direnv, args: [exec / $run.script new-window]}
    {tool: tmux, args: [new-window], path: (caller-path)}
  ]
}

def "test a Nix shell client borrows the running server PATH" [] {
  let run = (wrap [new-window "cargo run"] {IN_NIX_SHELL: impure, STUB_SERVER_PATH: $SERVER_PATH})

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

  assert equal $run.calls [
    {tool: direnv, args: [exec / $run.script split-window]}
    {tool: tmux, args: [-N show-environment -g PATH], path: (caller-path)}
    {tool: tmux, args: [-N split-window], path: $SERVER_PATH}
  ]
}

def "test every socket flag reaches the server probe" [] {
  let argv = [-S /tmp/sock -L name new-window]
  let run = (wrap $argv {NIX_BUILD_TOP: /tmp/nix-shell, STUB_SERVER_PATH: $SERVER_PATH})

  assert equal $run.calls [
    {tool: tmux, args: [-S /tmp/sock -L name -N show-environment -g PATH], path: (caller-path)}
    {tool: tmux, args: [-N ...$argv], path: $SERVER_PATH}
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
    wrap [has-session -t work] ($case | insert STUB_STATUS "3") --status 3
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
    let refused = ($case.client == null)
    let run = (wrap $case.argv {IN_NIX_SHELL: impure} --status (if $refused { 1 } else { 0 }))
    let context = $"argv: ($case.argv | to nuon)"
    let clients = ($run.calls | where {|call| "show-environment" not-in $call.args } | get args)

    if $refused {
      assert str contains $run.stderr $REFUSAL $context
      assert equal $clients [] $context
    } else {
      assert not ($run.stderr | str contains $REFUSAL) $context
      assert equal $clients [$case.client] $context
    }
  }
}
