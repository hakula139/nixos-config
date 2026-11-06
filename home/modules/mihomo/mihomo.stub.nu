#!/usr/bin/env nu

# ==================================================================================================
# mihomo Stub
# ==================================================================================================
# Stands in for mihomo in the start tests. Each call appends its arguments and parent pid to
# `STUB_LOG`, so a test can tell whether the start script exec'd mihomo or ran it as a child.
# ==================================================================================================

def --wrapped main [...args: string] {
  {args: $args, ppid: (ps | where pid == $nu.pid | get 0.ppid)}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG
}
