#!/usr/bin/env nu

# ==================================================================================================
# Tool Stub
# ==================================================================================================
# Stands in for every tool the auto-format hook runs. Each call appends the stub's own path, its
# working directory, its arguments, and whether `STALE` is set to `STUB_LOG`, one JSON line per
# call. It then prints `STUB_OUTPUT` and exits with `STUB_STATUS`, by default nothing and 0.
# ==================================================================================================

def --wrapped main [...args: string] {
  {bin: $env.CURRENT_FILE, cwd: $env.PWD, args: $args, stale: ("STALE" in $env)}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG
  print --no-newline ($env.STUB_OUTPUT? | default "")
  exit ($env.STUB_STATUS? | default "0" | into int)
}
