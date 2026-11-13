#!/usr/bin/env nu

# ==================================================================================================
# flock Stub
# ==================================================================================================
# Logs acquisitions, creates the persistent lock file, and optionally executes the refresh command.
# ==================================================================================================

def --wrapped main [--nonblock, lock: path, ...command: string] {
  if not $nonblock {
    print --stderr "Expected --nonblock"
    exit 2
  }
  if ($command | is-empty) {
    print --stderr "Missing refresh command"
    exit 2
  }

  {lock: $lock, command: $command}
  | to json --raw
  | $"($in)\n"
  | save --append $env.FLOCK_LOG

  touch $lock
  if ($env.STUB_FLOCK_HELD? | default "0") == "1" {
    exit 1
  }

  let executable = ($command | first)
  let arguments = ($command | skip 1)
  ^$executable ...$arguments
}
