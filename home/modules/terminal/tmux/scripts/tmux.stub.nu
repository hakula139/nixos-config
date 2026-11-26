#!/usr/bin/env nu

# ==================================================================================================
# tmux Stub
# ==================================================================================================
# Stands in for tmux in the tmux tests. Each call appends its arguments and PATH to `STUB_LOG`.
# `show-environment` prints `STUB_SERVER_PATH` or fails when unset, `display-message` prints
# `STUB_AFTER` for name queries and `STUB_INSPECT` (or fails when `STUB_INSPECT_FAIL=1`) otherwise,
# and every other call exits with `STUB_STATUS`.
# ==================================================================================================

def --wrapped main [...args: string] {
  {
    tool: "tmux"
    args: $args
    path: ([$env.PATH] | flatten | str join ":")
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  if "show-environment" in $args {
    if "STUB_SERVER_PATH" not-in $env {
      exit 1
    }
    print $"PATH=($env.STUB_SERVER_PATH)"
    exit 0
  } else if "display-message" in $args {
    let fmt = ($args | last)
    if ($fmt == "#{session_name}") or ($fmt == "#{window_name}") {
      print $env.STUB_AFTER
    } else if ($env.STUB_INSPECT_FAIL? == "1") {
      exit 1
    } else {
      print $env.STUB_INSPECT
    }
    exit 0
  }
  exit ($env.STUB_STATUS? | default "0" | into int)
}
