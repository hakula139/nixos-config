#!/usr/bin/env bash

# ==================================================================================================
# Rclone Mount Recovery
# ==================================================================================================

# cspell:ignore diskutil

set -euo pipefail

socket="$1"
mountpoint=$(realpath "$2")
shift 2

if [[ -e "$socket" ]]; then
  if lsof -t "$socket" >/dev/null; then
    printf 'Refusing to replace an active rclone socket: %s\n' "$socket" >&2
    exit 1
  else
    status=$?
    if [[ "$status" != 1 ]]; then
      exit "$status"
    fi
  fi
fi

mounts=$(mount -t nfs)
case "$mounts" in
  *" on $mountpoint ("*)
    diskutil unmount "$mountpoint"
    ;;
esac

rm -f "$socket"
exec "$@"
