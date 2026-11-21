#!/usr/bin/env nu

# ==================================================================================================
# Tunnel Control Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "control.nu")

const HOST = "bastion"
const RELAY = "system/org.nixos.tunnel"
const SSH = "gui/502/com.hakula.tunnel"

def control [
  argv: list<string>
  replies: list<record> = []
  state: string = "Running"
  --flag: string
  --follow-up: list<string>
]: nothing -> record {
  let log = (mktemp)
  let up_flag = (mktemp --directory | path join "tunnel.up")
  if $flag != null {
    $flag | save $up_flag
  }

  let invoke = {|args|
    (
      run-script $SCRIPT
        --user-name example-user
        --up-flag $up_flag
        ...$args
    )
  }

  let run = with-env {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_LOG: $log
    STUB_REPLIES: ($replies | to json --raw)
    STUB_TAILSCALE_STATE: $state
    STUB_UP_FLAG: $up_flag
  } {
    let first = (do $invoke $argv)
    let follow_up_run = if $follow_up != null {
      with-env {STUB_REPLIES: "[]"} { do $invoke $follow_up }
    }

    {first: $first, follow_up: $follow_up_run}
  }

  {
    run: $run.first
    follow_up: $run.follow_up
    calls: (open --raw $log | from json --objects)
    up_flag: ($up_flag | path exists)
  }
}

def launchctl-calls [result: record]: nothing -> list<record> {
  $result.calls
  | where command == "launchctl"
  | select command args
}

def "test startup targets the configured account and checks Tailscale first" [] {
  let id_call = {
    command: "id"
    args: [-u example-user]
  }

  let result = (control [up $HOST])
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert ($id_call in $result.calls)
  assert equal ($result.calls | where command != "id" | first) {
    command: "tailscale"
    args: [status --json]
  }
  assert equal (launchctl-calls $result) [
    [command args];
    ["launchctl" [kickstart $SSH]]
    ["launchctl" [kickstart $RELAY]]
  ]
}

def "test startup writes the host to the up flag before starting either service" [] {
  let result = (control [up $HOST])
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal ($result.calls | where command == "launchctl" | get up_host) [$HOST $HOST]
}

def "test startup preserves both jobs for the selected target" [] {
  let result = (control --flag $HOST [up $HOST])
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal (launchctl-calls $result | get args) [[kickstart $SSH] [kickstart $RELAY]]
}

def "test switching replaces the host and restarts only SSH" [] {
  let result = (control --flag $HOST [up "other-host"])
  assert equal $result.run.exit_code 0 $result.run.stderr

  let hosts = ($result.calls | where command == "launchctl" | get up_host)
  assert equal $hosts ["other-host" "other-host"]
  assert equal (launchctl-calls $result | get args) [[kickstart -k $SSH] [kickstart $RELAY]]
}

def "test startup without a host starts nothing" [] {
  for argv in [["up"] ["up" ""]] {
    let name = ($argv | to nuon)
    let result = (control $argv)

    assert not equal $result.run.exit_code 0 $name
    assert str contains $result.run.stderr "SSH host" $name
    assert equal ($result.calls | where command != "id") [] $name
    assert not $result.up_flag $name
  }
}

def "test a stopped Tailscale backend cannot start either tunnel service" [] {
  for state in ["Stopped" "NeedsLogin"] {
    let result = (control [up $HOST] [] $state)

    assert not equal $result.run.exit_code 0 $state
    assert str contains $result.run.stderr $state $state
    assert equal (launchctl-calls $result) [] $state
    assert not $result.up_flag $state
  }
}

def "test a startup failure reports the affected component and how to stop partial startup" [] {
  for target in [$SSH $RELAY] {
    let replies = [
      {
        action: "kickstart"
        target: $target
        exit_code: 5
        stderr: "service disabled"
      }
    ]

    let result = (control [up $HOST] $replies)

    assert not equal $result.run.exit_code 0 $target
    assert str contains $result.run.stderr "service disabled" $target
    assert str contains $result.run.stderr "sudo tunnel down" $target
    assert str contains $result.run.stdout "Ensuring ssh service..." $target
    assert not ($result.run.stdout | str contains "Tunnel startup requested") $target
  }
}

def "test retrying a partial startup only restarts SSH after an unfinished switch" [] {
  let cases = [
    [previous target first retry];
    [null $SSH [[kickstart $SSH]] [kickstart $SSH]]
    [$HOST $SSH [[kickstart -k $SSH]] [kickstart -k $SSH]]
    [$HOST $RELAY [[kickstart -k $SSH] [kickstart $RELAY]] [kickstart $SSH]]
  ]

  for case in $cases {
    let replies = [{action: "kickstart", target: $case.target, exit_code: 5}]

    let argv = [up "other-host"]
    let result = (control --flag $case.previous --follow-up $argv $argv $replies)
    assert not equal $result.run.exit_code 0
    assert equal $result.follow_up.exit_code 0 $result.follow_up.stderr

    let expected = ($case.first | append [$case.retry [kickstart $RELAY]])
    assert equal (launchctl-calls $result | get args) $expected
  }
}

def "test startup after a failed SSH stop replaces the previous job" [] {
  let replies = [{action: "kill", target: $SSH, exit_code: 5}]

  let result = (control --flag $HOST --follow-up [up "other-host"] [down] $replies)
  assert not equal $result.run.exit_code 0
  assert equal $result.follow_up.exit_code 0 $result.follow_up.stderr

  assert equal (launchctl-calls $result | get args) [
    [kill SIGTERM $SSH]
    [kill SIGTERM $RELAY]
    [kickstart -k $SSH]
    [kickstart $RELAY]
  ]
}

def "test stopping removes the up flag before stopping either service" [] {
  let result = (control --flag $HOST [down])
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal ($result.calls | where command == "launchctl" | get up_host) [null null]
}

def "test stopping tolerates an already stopped process for either service" [] {
  let cases = [
    [name relay ssh];
    ["both_stopped" 3 3]
    ["ssh_stopped" 0 3]
    ["relay_stopped" 3 0]
  ]

  for case in $cases {
    let replies = [
      [action target exit_code];
      ["kill" $RELAY $case.relay]
      ["kill" $SSH $case.ssh]
    ]

    let result = (control [down] $replies)
    assert equal $result.run.exit_code 0 $"($case.name): ($result.run.stderr)"

    assert equal (launchctl-calls $result) [
      [command args];
      ["launchctl" [kill SIGTERM $SSH]]
      ["launchctl" [kill SIGTERM $RELAY]]
    ] $case.name
  }
}

def "test an unexpected stop failure is reported after both services are attempted" [] {
  for target in [$RELAY $SSH] {
    let replies = [
      {
        action: "kill"
        target: $target
        exit_code: 5
        stderr: "permission denied"
      }
    ]

    let result = (control [down] $replies)

    assert not equal $result.run.exit_code 0 $target
    assert str contains $result.run.stderr "permission denied" $target
    assert equal (launchctl-calls $result) [
      [command args];
      ["launchctl" [kill SIGTERM $SSH]]
      ["launchctl" [kill SIGTERM $RELAY]]
    ] $target
  }
}

def "test status preserves the launchd details of both components" [] {
  let replies = [
    [action target stdout];
    ["print" $RELAY "relay: state = not running\nlast exit code = 0"]
    ["print" $SSH "ssh: state = running\npid = 1234"]
  ]

  let result = (control [status] $replies)
  assert equal $result.run.exit_code 0 $result.run.stderr

  for reply in $replies {
    assert str contains $result.run.stdout $reply.stdout $reply.target
  }
  assert equal (launchctl-calls $result) [
    [command args];
    ["launchctl" [print $SSH]]
    ["launchctl" [print $RELAY]]
  ]
}

def "test status names the host only while the up flag holds one" [] {
  let cases = [
    [flag stdout];
    [$HOST $"host: ($HOST)\nssh:\nrelay:\n"]
    ["" "ssh:\nrelay:\n"]
    [null "ssh:\nrelay:\n"]
  ]

  for case in $cases {
    let result = (control --flag $case.flag [status])
    assert equal $result.run.exit_code 0 $result.run.stderr

    assert equal $result.run.stdout $case.stdout $"flag: ($case.flag | to nuon)"
  }
}

def "test status identifies a pending target after a failed switch" [] {
  let replies = [{action: "kickstart", target: $SSH, exit_code: 5}]

  let result = (control --flag $HOST --follow-up [status] [up "other-host"] $replies)
  assert not equal $result.run.exit_code 0
  assert equal $result.follow_up.exit_code 0 $result.follow_up.stderr

  assert str contains $result.follow_up.stdout "host: other-host\nSSH target switch pending."
}
