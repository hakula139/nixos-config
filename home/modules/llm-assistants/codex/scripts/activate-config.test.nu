#!/usr/bin/env nu

# ==================================================================================================
# Codex Config Activation Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join activate-config.nu)

def command [command: string, extra: record = {}]: nothing -> record {
  {type: command, command: $command} | merge $extra
}

def "test activation records golden hook hashes and keeps other state" [] {
  let dir = (mktemp --directory | path expand --strict)
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
    configDir: $dir
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
          {
            matcher: $edits
            hooks: [(command /bin/gate {timeout: 100, statusMessage: "Checking"})]
          }
          {
            hooks: [(command "/bin/status working")]
          }
        ]
        SessionStart: [
          {
            matcher: compact
            hooks: [(command /bin/restore {timeout: 10, statusMessage: "Restoring context"})]
          }
          {
            matcher: "startup|resume|clear"
            hooks: [(command /bin/register)]
          }
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

  let trusted = (
    [
      [interrupt 0 0
        "sha256:5e55f2d7ba9fe9bc2f9449637467516df7a6515d0c4d2d4f92dd8313796d20e4"]
      [interrupt 0 1
        "sha256:5d6832087ad0ad90ac8bacb6ef2a558c565bb7d4d3969b94df0b715c05cd9dfd"]
      [permission_request 0 0
        "sha256:88b1c694c14770423c7290cf89139e3a31c7c0a094cb23c32e75221357e54791"]
      [permission_request 0 1
        "sha256:88304f35c7686a9c16dff3d1d0fcf522d05602cb13939b09ac8540ec55f000c1"]
      [post_tool_use 0 0
        "sha256:ae611e91dacde798572294eea30350e2261cd767dfcb4d1657d30c9217d0bbda"]
      [post_tool_use 1 0
        "sha256:21d718aef85523d6d1a3c123e1f8a9dc26fa6d879ac293697d02ea747639d1fc"]
      [post_tool_use 2 0
        "sha256:61296deaabf04eafe4472d463221d416903ca8b89b4ff9a2a4af0a82c146565b"]
      [session_end 0 0
        "sha256:1a2be0c709c51a7011e4a849b117dd1f04809857a259648f98ed7887dbbcba9a"]
      [session_start 0 0
        "sha256:af8c3db47468b115b8fc6b60f6d35afd11494f1a421bda876fb4fac6c7f958e1"]
      [session_start 1 0
        "sha256:fcae088b8e23f03f9d0199109d6f6a1a15aaf95751d4ba8bd4344c987455a801"]
      [stop 0 0
        "sha256:a48d48f3315c065473c178b65563ad0cc6da8b7098e06387a895937dc7ace2df"]
      [subagent_start 0 0
        "sha256:83089946ab1220d223a4a1381d5ac295cb12d309a638c02df0134697a9230493"]
      [subagent_stop 0 0
        "sha256:59f4b73a2411229cbc36b221441799f36622a486a2f069b3fcd5440101d257ff"]
      [user_prompt_submit 0 0
        "sha256:2177cc88452c247631f10c1985d043f1a9c5c8c1b90dc6f56d429b3b7938fbd5"]
    ]
    | reduce --fold {} {|row, acc|
      $acc | insert ([(do $key $row.0 $row.1 $row.2)] | into cell-path) {trusted_hash: $row.3}
    }
  )
  assert equal (open $target | get hooks.state) (
    $trusted
    | update ([(do $key stop 0 0)] | into cell-path) { insert enabled false }
    | insert ([$project_key] | into cell-path) {trusted_hash: "sha256:project"}
  )
}

def "test activation trusts hooks at the canonical config path" [] {
  for alias in [false true] {
    let dir = (mktemp --directory | path expand --strict)
    let canonical = ($dir | path join config)
    let config_dir = if $alias {
      mkdir $canonical
      let link = ($dir | path join alias)
      ^ln -s $canonical $link
      $link
    } else { $canonical }
    let config_file = ($dir | path join activation.json)
    let keybindings = [{command: hotkeyWindow, key: "Ctrl+Space"}]
    {
      configDir: $config_dir
      activeProfile: ($dir | path join missing-profile)
      settings: {
        tools: {}
        mcp_servers: {}
        hooks: {Stop: [{hooks: [(command "/bin/status done")]}]}
      }
      keybindings: $keybindings
    }
    | to json
    | save $config_file

    let run = (^$nu.current-exe --no-config-file $SCRIPT $config_file | complete)
    assert equal $run.exit_code 0 $run.stderr

    let key = $"($canonical)/config.toml:stop:0:0"
    assert equal (open ($canonical | path join config.toml) | get hooks.state) {
      $key: {
        trusted_hash: "sha256:a48d48f3315c065473c178b65563ad0cc6da8b7098e06387a895937dc7ace2df"
      }
    } $"symlinked config directory: ($alias)"
    assert equal (open ($canonical | path join keybindings.json)) $keybindings
  }
}

def "test activation imports only profiles in the canonical config directory" [] {
  for case in [
    {configAlias: false, profileAlias: false, contained: true}
    {configAlias: true, profileAlias: false, contained: true}
    {configAlias: false, profileAlias: true, contained: true}
    {configAlias: true, profileAlias: true, contained: false}
  ] {
    let dir = (mktemp --directory | path expand --strict)
    let canonical = ($dir | path join config)
    let alias = ($dir | path join alias)
    mkdir $canonical
    ^ln -s $canonical $alias
    let profile_dir = if $case.contained {
      if $case.profileAlias { $alias } else { $canonical }
    } else { $dir }
    let profile = ($profile_dir | path join native-profile.toml)
    let state = {"/repo": {trust_level: trusted}}
    {projects: $state} | to toml | save $profile
    let active = ($dir | path join active-profile)
    ^ln -s $profile $active
    let config_file = ($dir | path join activation.json)
    {
      configDir: (if $case.configAlias { $alias } else { $canonical })
      activeProfile: $active
      settings: {tools: {}, mcp_servers: {}, hooks: {}}
      keybindings: []
    }
    | to json
    | save $config_file

    let run = (^$nu.current-exe --no-config-file $SCRIPT $config_file | complete)
    assert equal $run.exit_code 0 $run.stderr

    let projects = (open ($canonical | path join config.toml) | get -o projects)
    assert equal $projects (if $case.contained { $state } else { null }) ($case | to nuon)
  }
}
