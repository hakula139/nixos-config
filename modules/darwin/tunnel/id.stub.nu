#!/usr/bin/env nu

# ==================================================================================================
# Identity Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  {command: id, args: $args} | to json --raw | $"($in)\n" | save --append $env.STUB_LOG
  print (if ($args | length) == 1 { "0" } else { "502" })
}
