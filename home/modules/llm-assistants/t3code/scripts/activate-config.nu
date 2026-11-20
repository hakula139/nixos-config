#!/usr/bin/env nu

# ==================================================================================================
# T3 Code Config Activation
# ==================================================================================================

use config-file.nu [open-record save-atomic]

# Merge managed defaults and provider instances while preserving user edits in T3 Code's settings.
def main [
  --config: path # Wrapper-supplied JSON with the T3 Code base directory and managed settings
] {
  let config = (open $config)
  ^install -d -m 0700 $config.baseDir
  let base_dir = ($config.baseDir | path expand --strict)
  let userdata_dir = ($base_dir | path join "userdata")
  ^install -d -m 0700 $userdata_dir
  let target = ($userdata_dir | path join "settings.json")

  let settings = (
    $config.defaults
    | merge deep --strategy overwrite (open-record $target)
    | merge deep --strategy overwrite {providerInstances: $config.providerInstances}
  )

  save-atomic ($settings | to json) $target
}
