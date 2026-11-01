#!/usr/bin/env nu

# ==================================================================================================
# Corporation Network Tunnel Control
# ==================================================================================================

# Start or stop both tunnel services. Startup requires Tailscale to be connected.
def main [
  user_name: string
  action: string # up, down, or status. Run up and down with sudo.
] {
  if $action not-in [up down status] {
    error make {msg: "Expected up, down, or status"}
  }
  if $action != "status" and (^id -u | into int) != 0 {
    error make {msg: $"Run sudo corp-tunnel ($action)"}
  }

  let uid = (^id -u $user_name | str trim)
  let targets = [
    {name: "ssh", target: $"gui/($uid)/com.hakula.corp-tunnel"}
    {name: "relay", target: "system/org.nixos.corp-tunnel"}
  ]

  match $action {
    "up" => {
      let state = (^tailscale status --json | from json | get BackendState)
      if $state != "Running" {
        error make {msg: $"Tailscale is ($state). Run sudo tailscale up first."}
      }
      for service in $targets {
        let result = (^launchctl kickstart $service.target | complete)
        if $result.exit_code != 0 {
          error make {
            msg: $"Could not start ($service.name): ($result.stderr | str trim). Run sudo corp-tunnel down to stop both services."
          }
        }
      }
      print "Tunnel startup requested. Use corp-tunnel status to inspect the services."
    }
    "down" => {
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
