#!/usr/bin/env nu

# Refresh remote directory metadata without downloading file contents.
def main [socket: string] {
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
