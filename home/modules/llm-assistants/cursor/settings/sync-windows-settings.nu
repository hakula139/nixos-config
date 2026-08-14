#!/usr/bin/env nu

# ==============================================================================
# Windows Cursor Settings Sync (WSL only)
# ==============================================================================
# Merge the Nix-managed Cursor settings into the Windows-side settings.json.
# ==============================================================================

use @windowsInterop@ *

# Cursor grows remote.SSH.remotePlatform (a host -> OS map) at runtime as new
# Remote-SSH hosts are added on Windows. Those entries are preserved, with Nix
# winning on shared keys.
const MERGE_KEY = "remote.SSH.remotePlatform"

const SOURCE = "@settings@"

def main [] {
  let target_dir = ([(windows-env-path APPDATA) "Cursor" "User"] | path join)
  let target = ([$target_dir "settings.json"] | path join)
  mkdir $target_dir

  let nix_settings = (open --raw $SOURCE | from json)
  let existing = (
    try { open --raw $target | from json | default {} } catch { {} }
  )

  let merged = (
    $nix_settings
    | upsert $MERGE_KEY (
      ($existing | get -o $MERGE_KEY | default {})
      | merge ($nix_settings | get -o $MERGE_KEY | default {})
    )
  )

  # 2 spaces matches `pkgs.formats.json`, so an unchanged sync is a no-op.
  let rendered = ($merged | to json --indent 2)
  if ($target | path exists) and ((open --raw $target) == $rendered) {
    print "Cursor settings: unchanged"
    return
  }

  $rendered | save --raw --force $target
  print $"Cursor settings: synced to ($target)"
}
