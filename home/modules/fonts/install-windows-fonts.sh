#!/usr/bin/env bash
set -euo pipefail

# Copies font files from Nix store to the Windows per-user font directory and
# registers them in the HKCU registry. The Windows interop helper is passed
# first, followed by font source directories.

WINDOWS_INTEROP="${1:?windows interop helper required}"
shift
# shellcheck source=lib/wsl/windows-interop.sh
source "$WINDOWS_INTEROP"

FONT_DIR="$(windows_env_path LOCALAPPDATA)/Microsoft/Windows/Fonts"
mkdir -p "$FONT_DIR"

installed=0
skipped=0

while IFS= read -r -d "" font; do
  name="$(basename "$font")"
  dest="$FONT_DIR/$name"
  if [[ -f "$dest" && "$(stat -c%s "$font")" == "$(stat -c%s "$dest")" ]]; then
    ((++skipped))
    continue
  fi
  cp -f "$font" "$dest"
  ((++installed))
done < <(
  find "$@" \
    -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' -o -name '*.otc' \) \
    -print0
)

printf 'Fonts: %d installed, %d unchanged\n' "$installed" "$skipped"

if ((installed > 0)); then
  WIN_FONT_DIR="$(wslpath -w "$FONT_DIR")"
  while IFS= read -r -d "" font; do
    name="$(basename "$font")"
    base="${name%.*}"
    ext="${name##*.}"
    case "$ext" in
      otf | otc) type="OpenType" ;;
      *) type="TrueType" ;;
    esac
    win_path="${WIN_FONT_DIR}\\${name}"
    reg.exe add \
      "HKCU\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" \
      /v "$base ($type)" /t REG_SZ /d "$win_path" /f </dev/null >/dev/null 2>&1 || true
  done < <(
    find "$FONT_DIR" -maxdepth 1 -type f \
      \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' -o -name '*.otc' \) \
      -print0
  )
  echo "Fonts registered. Restart applications to use new fonts."
fi
