#!/usr/bin/env nu

# ==============================================================================
# Rclone Metadata Refresh
# ==============================================================================
# Run with --help for usage.
# ==============================================================================

# Refresh remote directory metadata without downloading file contents.
# A missing socket is skipped while the mount is stopped.
def main [
  socket: string # Unix socket for the mount's rclone remote-control API
] {
  if not ($socket | path exists) {
    return
  }

  let response = (^rclone rc --unix-socket $socket vfs/refresh recursive=true | complete)
  if $response.exit_code != 0 {
    print --stderr $response.stderr
    exit $response.exit_code
  }

  let failures = (
    $response.stdout
    | from json
    | get result
    | transpose directory status
    | where status != "OK"
  )
  if not ($failures | is-empty) {
    print --stderr ($failures | to json)
    exit 1
  }
}
