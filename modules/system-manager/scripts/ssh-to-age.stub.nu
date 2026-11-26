#!/usr/bin/env nu

# ==================================================================================================
# ssh-to-age Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  {
    command: "ssh-to-age"
    args: $args
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  print $"AGE-SECRET-KEY-STUB-($args | last | path basename)"
}
