#!/usr/bin/env nu

# ==================================================================================================
# Codex Config Activation Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join activate-config.nu)

# What the app server of the `codex` on PATH reports for the hooks under `codex_home`.
def codex-hooks [codex_home: string]: nothing -> record {
  let requests = (
    [
      {jsonrpc: "2.0", id: 1, method: initialize, params: {clientInfo: {name: test, version: "0"}}}
      {jsonrpc: "2.0", method: initialized}
      {jsonrpc: "2.0", id: 2, method: hooks/list, params: {cwds: [$codex_home]}}
    ]
    | each { to json --raw }
    | str join "\n"
  )
  # The app server exits at the end of its input without answering, so input stays open until the
  # reply arrives.
  let script = (
    '
    coproc server { exec codex app-server; }
    printf "%s\n" "$REQUESTS" >&"${server[1]}"
    while read -r line <&"${server[0]}"; do
      case $line in *"\"id\":2"*) printf "%s\n" "$line"; break ;; esac
    done
    kill "$server_PID"
    '
    | str dedent
  )
  let run = with-env {HOME: $codex_home, CODEX_HOME: $codex_home, REQUESTS: $requests} {
    ^timeout 60 bash -c $script | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  $run.stdout | from json | get result.data.0
}

def command [command: string, extra: record = {}]: nothing -> record {
  {type: command, command: $command} | merge $extra
}

def "test activation records the hash codex trusts and keeps other state" [] {
  let root = (mktemp --directory | path expand --strict)
  let dir = ($root | path join codex)
  mkdir $dir
  let linked_dir = ($root | path join linked-codex)
  ^ln -s $dir $linked_dir

  let target = ($dir | path join config.toml)
  let config_file = ($dir | path join activation.json)
  let key = {|event: string, group: int, handler: int| $"($target):($event):($group):($handler)" }
  let project_key = "/repo/.codex/config.toml:stop:0:0"

  let prior_state = {
    (do $key stop 0 0): {enabled: false, trusted_hash: "sha256:stale"}
    $project_key: {trusted_hash: "sha256:project"}
  }
  {hooks: {state: $prior_state}} | to toml | save $target
  let edits = "Edit|Write"
  {
    configDir: $linked_dir
    activeProfile: ($dir | path join missing-profile)
    settings: {
      tools: {}
      mcp_servers: {}
      hooks: {
        PostToolUse: [
          {
            matcher: $edits
            hooks: [(command /bin/format {timeout: 120, statusMessage: "Formatting edited files"})]
          }
          {matcher: $edits, hooks: [(command /bin/gate {timeout: 100, statusMessage: "Checking"})]}
          {hooks: [(command "/bin/status working")]}
        ]
        SessionStart: [
          {
            matcher: compact
            hooks: [(command /bin/restore {timeout: 10, statusMessage: "Restoring context"})]
          }
          {matcher: "startup|resume|clear", hooks: [(command /bin/register)]}
        ]
        PermissionRequest: [
          {hooks: [(command "/bin/status waiting") (command /bin/instant {timeout: 0})]}
        ]
        SubagentStart: [{hooks: [(command "/bin/status working")]}]
        SubagentStop: [{hooks: [(command "/bin/status working")]}]
        UserPromptSubmit: [{hooks: [(command "/bin/status working")]}]
        SessionEnd: [{hooks: [(command /bin/end {timeout: 5})]}]
        Interrupt: [{hooks: [(command /bin/interrupted) (command /bin/abort {timeout: 0})]}]
        Stop: [{matcher: ignored, hooks: [(command "/bin/status done")]}]
      }
    }
    keybindings: []
  }
  | to json
  | save $config_file

  let run = (^$nu.current-exe --no-config-file $SCRIPT $config_file | complete)
  assert equal $run.exit_code 0 $run.stderr
  let listed = (codex-hooks $linked_dir)

  assert equal $listed.errors []
  assert equal $listed.warnings [$"clamping SessionEnd hook timeout to 3s in ($target)"]
  let hooks = ($listed.hooks | sort-by key)
  assert equal ($hooks | select key trustStatus timeoutSec) (
    [
      [(do $key interrupt 0 0) 1]
      [(do $key interrupt 0 1) 1]
      [(do $key permission_request 0 0) 600]
      [(do $key permission_request 0 1) 1]
      [(do $key post_tool_use 0 0) 120]
      [(do $key post_tool_use 1 0) 100]
      [(do $key post_tool_use 2 0) 600]
      [(do $key session_end 0 0) 3]
      [(do $key session_start 0 0) 10]
      [(do $key session_start 1 0) 600]
      [(do $key stop 0 0) 600]
      [(do $key subagent_start 0 0) 600]
      [(do $key subagent_stop 0 0) 600]
      [(do $key user_prompt_submit 0 0) 600]
    ]
    | each {|row| {key: $row.0, trustStatus: trusted, timeoutSec: $row.1} }
  )
  let trusted = ($hooks | reduce --fold {} {|hook, acc|
    $acc | insert ([$hook.key] | into cell-path) {trusted_hash: $hook.currentHash}
  })
  assert equal (open $target | get hooks.state) (
    $trusted
    | update ([(do $key stop 0 0)] | into cell-path) { insert enabled false }
    | insert ([$project_key] | into cell-path) {trusted_hash: "sha256:project"}
  )
}
