#!/usr/bin/env nu

# ==================================================================================================
# Launchctl Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  {
    command: launchctl
    args: $args
    up_flag: ($env.STUB_UP_FLAG | path exists)
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  let reply = (
    $env.STUB_REPLIES
    | from json
    | where {|reply| $reply.action == $args.0 and $reply.target == ($args | last)}
    | first 1
    | get -o 0
    | default {}
  )

  print --no-newline ($reply | get -o stdout | default "")
  print -e --no-newline ($reply | get -o stderr | default "")
  exit ($reply | get -o exit_code | default 0)
}
