#!/usr/bin/env nu

# ==================================================================================================
# Tunnel Control Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "control.nu")

const HOST = "bastion"
const RELAY = "system/org.nixos.tunnel"
const SSH = "gui/502/com.hakula.tunnel"

def control [
  argv: list<string>
  replies: list<record> = []
  state: string = "Running"
  --requested
]: nothing -> record {
  let log = (mktemp)
  let up_flag = (mktemp --directory | path join "tunnel.up")
  if $requested {
    $HOST | save $up_flag
  }

  let run = with-env {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_LOG: $log
    STUB_REPLIES: ($replies | to json --raw)
    STUB_TAILSCALE_STATE: $state
    STUB_UP_FLAG: $up_flag
  } {
    (
      ^$nu.current-exe --no-config-file $SCRIPT
        --user-name example-user
        --up-flag $up_flag
        ...$argv
      | complete
    )
  }

  {
    run: $run
    calls: (open --raw $log | from json --objects)
    up_flag: ($up_flag | path exists)
  }
}

def launchctl-calls [result: record]: nothing -> list<record> {
  $result.calls
  | where command == "launchctl"
  | select command args
  | sort-by {|call| $call.args | last}
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
    {
      command: "launchctl"
      args: [kickstart $SSH]
    }
    {
      command: "launchctl"
      args: [kickstart $RELAY]
    }
  ]
}

def "test startup writes the host to the up flag before starting either service" [] {
  let result = (control [up $HOST])
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal ($result.calls | where command == "launchctl" | get up_host) [$HOST $HOST]
}

def "test startup without a host starts nothing" [] {
  for argv in [["up"] ["up" ""]] {
    let result = (control $argv)

    assert not equal $result.run.exit_code 0 ($argv | to nuon)
    assert str contains $result.run.stderr "SSH host" ($argv | to nuon)
    assert equal ($result.calls | where command != "id") [] ($argv | to nuon)
    assert not $result.up_flag ($argv | to nuon)
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
    assert equal $result.run.stdout "" $target
  }
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
      {
        action: "kill"
        target: $RELAY
        exit_code: $case.relay
      }
      {
        action: "kill"
        target: $SSH
        exit_code: $case.ssh
      }
    ]

    let result = (control [down] $replies)
    assert equal $result.run.exit_code 0 $"($case.name): ($result.run.stderr)"

    assert equal (launchctl-calls $result) [
      {
        command: "launchctl"
        args: [kill SIGTERM $SSH]
      }
      {
        command: "launchctl"
        args: [kill SIGTERM $RELAY]
      }
    ] $case.name
  }
}

def "test stopping removes the up flag before stopping either service" [] {
  let result = (control --requested [down])
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal ($result.calls | where command == "launchctl" | get up_host) [null null]
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
      {
        command: "launchctl"
        args: [kill SIGTERM $SSH]
      }
      {
        command: "launchctl"
        args: [kill SIGTERM $RELAY]
      }
    ] $target
  }
}

def "test status preserves the launchd details of both components" [] {
  let replies = [
    {
      action: "print"
      target: $RELAY
      stdout: "relay: state = not running\nlast exit code = 0"
    }
    {
      action: "print"
      target: $SSH
      stdout: "ssh: state = running\npid = 1234"
    }
  ]

  let result = (control [status] $replies)
  assert equal $result.run.exit_code 0 $result.run.stderr

  for reply in $replies {
    assert str contains $result.run.stdout $reply.stdout $reply.target
  }
  assert equal (launchctl-calls $result) [
    {
      command: "launchctl"
      args: [print $SSH]
    }
    {
      command: "launchctl"
      args: [print $RELAY]
    }
  ]
}
