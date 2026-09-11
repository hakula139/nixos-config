#!/usr/bin/env nu

# ==============================================================================
# Codex Config Activation
# ==============================================================================

# Apply managed settings while preserving Codex's mutable user state.
def main [config_file: string] {
  let config = (open $config_file)
  let target = ($config.configDir | path join 'config.toml')
  ^install -d -m 0700 $config.configDir

  mut current = if ($target | path exists) {
    open --raw $target | from toml
  } else { {} }

  # Native profile files may contain project trust and hook review state.
  if ($config.activeProfile | path exists) {
    let profile = (^readlink $config.activeProfile | str trim)
    if ($profile | path dirname) == $config.configDir {
      $current = ($current | merge deep --strategy overwrite (open --raw $profile | from toml))
    }
  }

  mut settings = ($current
    | merge deep --strategy overwrite $config.settings
    | merge ($config.settings | select tools mcp_servers hooks))
  let hook_state = ($current | get -o hooks.state)
  if $hook_state != null {
    $settings = ($settings | upsert hooks.state $hook_state)
  }

  let temporary = (^mktemp $"--tmpdir=($config.configDir)" '.config.XXXXXXXXXX' | str trim)

  try {
    $settings | to toml | save --force $temporary
    ^chmod 600 $temporary
    ^mv --force $temporary $target
  } catch {|error|
    rm --force $temporary
    error make $error
  }
}
