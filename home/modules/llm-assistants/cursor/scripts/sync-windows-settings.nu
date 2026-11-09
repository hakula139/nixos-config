#!/usr/bin/env nu

# ==================================================================================================
# Windows Cursor Settings Sync (WSL only)
# ==================================================================================================
# Merge the Nix-managed Cursor settings into the Windows-side settings.json and replace the
# Windows-side keybindings.json with the Nix-managed one.
# ==================================================================================================

# Cursor grows remote.SSH.remotePlatform (a host -> OS map) at runtime as new Remote-SSH hosts are
# added on Windows. Those entries are preserved, with Nix winning on shared keys.
const MERGE_KEY = "remote.SSH.remotePlatform"

# Merge the Nix settings into an existing settings file and return the rendered JSON.
def merge-settings [source: path, target: path]: nothing -> string {
  let nix_settings = (open --raw $source | from json)
  let existing = try {
    open --raw $target | from json | default {}
  } catch {
    {}
  }

  let merged = (
    $nix_settings
    | upsert $MERGE_KEY (
      ($existing | get -o $MERGE_KEY | default {})
      | merge ($nix_settings | get -o $MERGE_KEY | default {})
    )
  )

  # 2 spaces matches `pkgs.formats.json`, so an unchanged sync is a no-op.
  $merged | to json --indent 2
}

# Write a file only when its content differs from the rendered content.
def write-if-changed [label: string, rendered: string, target: path]: nothing -> nothing {
  if ($target | path exists) and ((open --raw $target) == $rendered) {
    print $"($label): unchanged"
    return
  }

  $rendered | save --raw --force $target
  print $"($label): synced to ($target)"
}

# Syncs the Windows-side Cursor settings and keybindings.
def main [
  --config: path # Wrapper-supplied JSON with the files to sync and the Windows interop helper
]: nothing -> nothing {
  let config = (open $config)
  let app_data = (^$config.windowsInterop APPDATA | str trim)
  let target_dir = ([$app_data "Cursor/User"] | path join)
  let settings_target = ([$target_dir "settings.json"] | path join)
  let keybindings_target = ([$target_dir "keybindings.json"] | path join)
  mkdir $target_dir

  let settings = (merge-settings $config.settingsFile $settings_target)
  write-if-changed "Cursor settings" $settings $settings_target
  write-if-changed "Cursor keybindings" (open --raw $config.keybindingsFile) $keybindings_target
}
