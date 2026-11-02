#!/usr/bin/env nu

# ==================================================================================================
# Formatter Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  {cwd: $env.PWD, args: $args}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  print --no-newline $env.STUB_OUTPUT
  if ($env.STUB_STDERR | is-not-empty) { print --stderr $env.STUB_STDERR }
  exit ($env.STUB_EXIT | into int)
}
