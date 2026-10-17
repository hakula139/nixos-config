#!/usr/bin/env nu

# ==================================================================================================
# tmux Stub
# ==================================================================================================
# Stands in for tmux in the wrapper tests. Each call appends its arguments and PATH to `STUB_LOG`.
# The server PATH probe prints `STUB_SERVER_PATH`, or fails when no server is set, and every other
# call exits with `STUB_STATUS`.
# ==================================================================================================

def --wrapped main [...args: string] {
  {tool: tmux, args: $args, path: ([$env.PATH] | flatten | str join ":")}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  if "show-environment" in $args {
    if "STUB_SERVER_PATH" not-in $env {
      exit 1
    }
    print $"PATH=($env.STUB_SERVER_PATH)"
    exit 0
  }
  exit ($env.STUB_STATUS? | default "0" | into int)
}
