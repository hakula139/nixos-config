#!/usr/bin/env nu

# ==================================================================================================
# T3 Code Config Activation
# ==================================================================================================

# Read a JSON file as a record, or an empty one when it is missing, empty, or not a record.
def open-record [path: path]: nothing -> record {
  if not ($path | path exists) {
    return {}
  }

  let content = (open $path)
  if ($content | describe | str starts-with "record") { $content } else { {} }
}

def save-config [content: string, target: path] {
  let temporary = (
    mktemp --tmpdir-path ($target | path dirname) $".($target | path basename).XXXXXXXXXX"
  )

  try {
    $content | save --force $temporary
    ^mv --force $temporary $target
  } catch {|error|
    rm --force $temporary
    error make $error
  }
}

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

  save-config ($settings | to json) $target
}
