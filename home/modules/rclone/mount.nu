#!/usr/bin/env nu

# ==================================================================================================
# Rclone Mount Recovery
# ==================================================================================================

# Recover a stopped NFS mount before replacing this process with rclone.
def --wrapped main [
  socket: string # Unix socket for the mount's rclone remote-control API
  mountpoint: string # Managed NFS mount directory
  command: string # Rclone executable
  ...args: string # Arguments forwarded to rclone
] {
  # Resolving the mount itself can block while its NFS server is unavailable.
  let mountpoint = (
    $mountpoint
    | path dirname
    | path expand --strict
    | path join ($mountpoint | path basename)
  )

  if ($socket | path exists) {
    let owner = (^lsof -t $socket | complete)
    if $owner.exit_code == 0 {
      print --stderr $"Refusing to replace an active rclone socket: ($socket)"
      exit 1
    }
    if $owner.exit_code != 1 {
      print --stderr $owner.stderr
      exit $owner.exit_code
    }
  }

  let mounts = (^mount -t nfs)
  if ($mounts | str contains (' on ' + $mountpoint + ' (')) {
    ^diskutil unmount $mountpoint
  }

  rm --force $socket
  exec $command ...$args
}
