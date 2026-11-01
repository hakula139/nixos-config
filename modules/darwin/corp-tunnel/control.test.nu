#!/usr/bin/env nu

# ==================================================================================================
# Tunnel Control Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join control.nu)
const RELAY = "system/org.nixos.corp-tunnel"
const SSH = "gui/502/com.hakula.corp-tunnel"

def control [action: string, replies: list<record> = [], state: string = "Running"]: nothing -> record {
  let log = (mktemp)
  let run = with-env {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_LOG: $log
    STUB_REPLIES: ($replies | to json --raw)
    STUB_TAILSCALE_STATE: $state
  } {
    ^$nu.current-exe --no-config-file $SCRIPT example-user $action | complete
  }

  {run: $run, calls: (open --raw $log | from json --objects)}
}

def launchctl-calls [result: record]: nothing -> list<record> {
  $result.calls | where command == launchctl | sort-by {|call| $call.args | last}
}

def "test a stopped Tailscale backend cannot start either tunnel service" [] {
  for state in [Stopped NeedsLogin] {
    let result = (control up [] $state)

    assert not equal $result.run.exit_code 0 $state
    assert ($result.run.stderr | str contains $state) $state
    assert equal (launchctl-calls $result) [] $state
  }
}

def "test startup targets the configured account and checks Tailscale first" [] {
  let result = (control up)
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert ($result.calls | any {|call| $call == {command: id, args: [-u example-user]}})
  assert equal ($result.calls | where command != id | first) {
    command: tailscale, args: [status --json]
  }
  assert equal (launchctl-calls $result) [
    {command: launchctl, args: [kickstart $SSH]}
    {command: launchctl, args: [kickstart $RELAY]}
  ]
}

def "test a startup failure reports the affected component and how to stop partial startup" [] {
  for target in [$SSH $RELAY] {
    let replies = [{action: kickstart, target: $target, exit_code: 5, stderr: "service disabled"}]

    let result = (control up $replies)

    assert not equal $result.run.exit_code 0 $target
    assert ($result.run.stderr | str contains "service disabled") $target
    assert ($result.run.stderr | str contains "sudo corp-tunnel down") $target
    assert equal $result.run.stdout "" $target
  }
}

def "test stopping tolerates an already stopped process for either service" [] {
  for codes in [[3 3] [0 3] [3 0]] {
    let replies = [
      {action: kill, target: $RELAY, exit_code: $codes.0}
      {action: kill, target: $SSH, exit_code: $codes.1}
    ]

    let result = (control down $replies)
    assert equal $result.run.exit_code 0 $result.run.stderr

    assert equal (launchctl-calls $result) [
      {command: launchctl, args: [kill SIGTERM $SSH]}
      {command: launchctl, args: [kill SIGTERM $RELAY]}
    ]
  }
}

def "test an unexpected stop failure is reported after both services are attempted" [] {
  for target in [$RELAY $SSH] {
    let replies = [{action: kill, target: $target, exit_code: 5, stderr: "permission denied"}]

    let result = (control down $replies)

    assert not equal $result.run.exit_code 0 $target
    assert ($result.run.stderr | str contains "permission denied") $target
    assert equal (launchctl-calls $result) [
      {command: launchctl, args: [kill SIGTERM $SSH]}
      {command: launchctl, args: [kill SIGTERM $RELAY]}
    ] $target
  }
}

def "test status preserves the launchd details of both components" [] {
  let replies = [
    {action: print, target: $RELAY, stdout: "relay: state = not running\nlast exit code = 0"}
    {action: print, target: $SSH, stdout: "ssh: state = running\npid = 1234"}
  ]

  let result = (control status $replies)
  assert equal $result.run.exit_code 0 $result.run.stderr

  for reply in $replies {
    assert ($result.run.stdout | str contains $reply.stdout) $reply.target
  }
  assert equal (launchctl-calls $result) [
    {command: launchctl, args: [print $SSH]}
    {command: launchctl, args: [print $RELAY]}
  ]
}
