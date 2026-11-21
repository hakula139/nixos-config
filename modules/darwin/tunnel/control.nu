#!/usr/bin/env nu

# ==================================================================================================
# Network Tunnel Control
# ==================================================================================================

use config-file.nu [save-atomic]

def selected-host [up_flag: path] {
  if ($up_flag | path exists) { open --raw $up_flag }
}

def start-service [service: record, --restart] {
  let flags = if $restart { [-k] } else { [] }
  let action = if $restart { "Starting" } else { "Ensuring" }
  print $"($action) ($service.name) service..."

  let result = (^launchctl kickstart ...$flags $service.target | complete)
  if $result.exit_code != 0 {
    error make {
      msg: $"Could not start ($service.name): ($result.stderr | str trim). Run sudo tunnel down to stop both services."
    }
  }
}

# Start or stop both tunnel services. Startup requires Tailscale to be connected, and launchd then
# restarts a failed service until tunnel down or a reboot.
# Run up and down one at a time.
def main [
  action: string # One of up, down, or status, with up and down run under sudo
  host?: string # SSH configuration entry that up connects through
  --user-name: string # Wrapper-supplied account that owns the SSH agent
  --up-flag: path # Wrapper-supplied file holding the SSH host, which both services need non-empty
] {
  if $action not-in ["up" "down" "status"] {
    error make {msg: "Expected up, down, or status"}
  }

  if $action == "up" and ($host | is-empty) {
    error make {msg: "Expected an SSH host. Run sudo tunnel up <host>."}
  }

  if $action != "status" and (^id -u | into int) != 0 {
    error make {msg: $"Run sudo tunnel ($action)"}
  }

  let uid = (^id -u $user_name | str trim)
  let targets = [
    [name target];
    ["ssh" $"gui/($uid)/com.hakula.tunnel"]
    ["relay" "system/org.nixos.tunnel"]
  ]
  let switch_pending = $"($up_flag).switch-pending"

  match $action {
    "up" => {
      let state = (
        ^tailscale status --json
        | from json
        | get BackendState
      )
      if $state != "Running" {
        error make {msg: $"Tailscale is ($state). Run sudo tailscale up first."}
      }

      let previous = (selected-host $up_flag)
      # An interrupted down can leave SSH running after removing the host marker.
      let changed = $previous != $host
      let restart_ssh = $changed or ($switch_pending | path exists)
      if $changed {
        # A failed restart can leave SSH on the previous host.
        touch $switch_pending
        save-atomic $host $up_flag --mode "0644"
      }

      for service in $targets {
        let restart = $service.name == "ssh" and $restart_ssh
        start-service $service --restart=$restart
        if $restart {
          rm --force $switch_pending
        }
      }

      print "Tunnel startup requested. Use tunnel status to inspect the services."
    }

    "down" => {
      rm --force $up_flag $switch_pending

      mut failures = []
      for service in $targets {
        let result = (^launchctl kill SIGTERM $service.target | complete)
        if $result.exit_code not-in [0 3] {
          $failures = ($failures | append $"($service.name): ($result.stderr | str trim)")
        }
      }

      if ($failures | is-not-empty) {
        error make {msg: ($failures | str join "\n")}
      }

      print "Tunnel services stopped."
    }

    "status" => {
      let host = (selected-host $up_flag)
      if ($host | is-not-empty) {
        print $"host: ($host)"
        if ($switch_pending | path exists) {
          print "SSH target switch pending."
        }
      }

      for service in $targets {
        print $"($service.name):"
        ^launchctl print $service.target
      }
    }
  }
}
