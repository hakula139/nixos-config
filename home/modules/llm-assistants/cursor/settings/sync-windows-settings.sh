#!/usr/bin/env bash
set -euo pipefail

WINDOWS_INTEROP="${1:?windows interop helper required}"
SOURCE="${2:?source settings path required}"
# shellcheck source=lib/wsl/windows-interop.sh
source "$WINDOWS_INTEROP"

TARGET_DIR="$(windows_env_path APPDATA)/Cursor/User"
TARGET="$TARGET_DIR/settings.json"
mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET" ]] && cmp -s "$SOURCE" "$TARGET"; then
  echo "Cursor settings: unchanged"
  exit 0
fi

install -m 0644 "$SOURCE" "$TARGET"
echo "Cursor settings: synced to $TARGET"
