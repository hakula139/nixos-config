#!/usr/bin/env nu

# ==================================================================================================
# SSH Stub
# ==================================================================================================
# Stands in for `ssh -G`, printing the hostname that `STUB_SSH_HOSTNAMES` maps the given target to,
# or its host part if the target is unmapped, or failing with `STUB_SSH_ERROR`.
# ==================================================================================================

def --wrapped main [...args: string] {
  let exit_code = ($env.STUB_SSH_EXIT? | default "0" | into int)
  if $exit_code != 0 {
    print -e ($env.STUB_SSH_ERROR? | default "ssh: test failure")
    exit $exit_code
  }
  let target = ($args | last)
  let host = ($target | split row "@" | last)
  let hostnames = ($env.STUB_SSH_HOSTNAMES? | default "{}" | from json)
  let hostname = (
    $hostnames
    | get -o $target
    | default ($hostnames | get -o $host | default $host)
  )
  print $"host ($host)"
  print $"hostname ($hostname)"
}
