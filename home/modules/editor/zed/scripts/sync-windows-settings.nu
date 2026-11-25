#!/usr/bin/env nu

# ==================================================================================================
# Windows Zed Settings Sync (WSL only)
# ==================================================================================================
# Sync the Nix-managed Zed settings.json and keymap.json to the Windows %APPDATA%\Zed directory.
# ==================================================================================================

use config-file.nu [save-atomic]

# Write a file only when its content differs from the rendered content.
def write-if-changed [label: string, rendered: string, target: path]: nothing -> nothing {
  if ($target | path exists) and ((open --raw $target) == $rendered) {
    print $"($label): unchanged"
    return
  }

  save-atomic $rendered $target
  print $"($label): synced to ($target)"
}

# Syncs the Windows-side Zed settings and keymaps.
def main [
  --config: path # Wrapper-supplied JSON with the files to sync and the Windows interop helper
]: nothing -> nothing {
  let config = (open $config)
  let app_data = (^$config.windowsInterop APPDATA | str trim)
  let target_dir = ($app_data | path join "Zed")
  let settings_target = ($target_dir | path join "settings.json")
  let keymap_target = ($target_dir | path join "keymap.json")
  mkdir $target_dir

  write-if-changed "Zed settings" (open --raw $config.settingsFile) $settings_target
  write-if-changed "Zed keymap" (open --raw $config.keymapFile) $keymap_target
}
