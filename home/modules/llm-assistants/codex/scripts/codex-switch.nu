#!/usr/bin/env nu

# Switch the default Codex profile, or list the available ones.
def main [
  config_dir: string
  state_dir: string
  default_profile: string
  profile?: string
  --list (-l)
] {
  let active_link = ($state_dir | path join "active-profile")
  let current = try {
    readlink $active_link | path basename | str replace '.config.toml' ''
  } catch { $default_profile }
  let profiles = (glob ($config_dir | path join '*.config.toml')
    | path basename | str replace '.config.toml' '' | sort)

  if $list or ($profile | is-empty) {
    print ($profiles | each {|name| {profile: $name, active: ($name == $current)} } | table)
    return
  }

  if $profile not-in $profiles {
    error make {msg: $"Unknown profile: ($profile). Available: ($profiles | str join ', ')"}
  }

  mkdir $state_dir
  ln -sf ($config_dir | path join $"($profile).config.toml") $active_link
  print $"Switched to profile: ($profile)"
  print "Restart Codex for changes to take effect."
}
