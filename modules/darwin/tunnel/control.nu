#!/usr/bin/env nu

# ==================================================================================================
# Network Tunnel Control
# ==================================================================================================

# Start or stop both tunnel services. Startup requires Tailscale to be connected, and launchd then
# restarts a failed service until tunnel down or a reboot.
def main [
  action: string # up, down, or status. Run up and down with sudo.
  --user-name: string # Account that owns the SSH agent
  --up-flag: path # File both services require to run
] {
  if $action not-in [up down status] {
    error make {msg: "Expected up, down, or status"}
  }

  if $action != "status" and (^id -u | into int) != 0 {
    error make {msg: $"Run sudo tunnel ($action)"}
  }

  let uid = (^id -u $user_name | str trim)
  let targets = [
    {
      name: "ssh"
      target: $"gui/($uid)/com.hakula.tunnel"
    }
    {
      name: "relay"
      target: "system/org.nixos.tunnel"
    }
  ]

  match $action {
    "up" => {
      let state = (^tailscale status --json | from json | get BackendState)
      if $state != "Running" {
        error make {msg: $"Tailscale is ($state). Run sudo tailscale up first."}
      }

      touch $up_flag

      for service in $targets {
        let result = (^launchctl kickstart $service.target | complete)
        if $result.exit_code != 0 {
          error make {
            msg: $"Could not start ($service.name): ($result.stderr | str trim). Run sudo tunnel down to stop both services."
          }
        }
      }

      print "Tunnel startup requested. Use tunnel status to inspect the services."
    }

    "down" => {
      rm --force $up_flag

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
      for service in $targets {
        print $"($service.name):"
        ^launchctl print $service.target
      }
    }
  }
}
