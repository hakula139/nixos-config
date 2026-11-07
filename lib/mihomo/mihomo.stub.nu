#!/usr/bin/env nu

# ==================================================================================================
# mihomo Stub
# ==================================================================================================
# Stands in for mihomo in the start and update tests. Each call appends its arguments and parent pid
# to `STUB_LOG`, so a test can tell whether the start script exec'd mihomo or ran it as a child. A
# `-t` call exits with `STUB_MIHOMO_STATUS`, so the update tests can reject a staged config.
# ==================================================================================================

def --wrapped main [...args: string] {
  if "STUB_LOG" in $env {
    {args: $args, ppid: (ps | where pid == $nu.pid | get 0.ppid)}
    | to json --raw
    | $"($in)\n"
    | save --append $env.STUB_LOG
  }

  if ("-t" in $args) {
    exit ($env.STUB_MIHOMO_STATUS | into int)
  }
}
