#!/usr/bin/env bash
set -euo pipefail

WINDOWS_INTEROP="${1:?windows interop helper required}"
SOURCE="${2:?source settings path required}"
# shellcheck source=lib/wsl/windows-interop.sh
source "$WINDOWS_INTEROP"

TARGET_DIR="$(windows_env_path APPDATA)/Cursor/User"
TARGET="$TARGET_DIR/settings.json"
mkdir -p "$TARGET_DIR"

# Cursor grows remote.SSH.remotePlatform (a host -> OS map) at runtime as new
# Remote-SSH hosts are added on Windows. Merge those entries under the
# Nix-managed settings so a sync preserves them, with Nix winning on shared keys.
MERGE_KEY="remote.SSH.remotePlatform"

merged="$(mktemp)"
trap 'rm -f "$merged"' EXIT

if [[ -f "$TARGET" ]] && jq -e . "$TARGET" >/dev/null 2>&1; then
  jq -n --arg k "$MERGE_KEY" --slurpfile source "$SOURCE" --slurpfile target "$TARGET" \
    '$source[0] | .[$k] = (($target[0][$k] // {}) + ($source[0][$k] // {}))' >"$merged"
else
  cp "$SOURCE" "$merged"
fi

if [[ -f "$TARGET" ]] && cmp -s "$merged" "$TARGET"; then
  echo "Cursor settings: unchanged"
  exit 0
fi

install -m 0644 "$merged" "$TARGET"
echo "Cursor settings: synced to $TARGET"
