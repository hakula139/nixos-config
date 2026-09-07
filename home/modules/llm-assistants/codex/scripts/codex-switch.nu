#!/usr/bin/env nu

# ==============================================================================
# Codex Auth Profile Switcher
# ==============================================================================

# `glob` rather than `ls`, which raises when no profile has been written yet.
def profile-names [config_dir: string]: nothing -> list<string> {
  glob ($config_dir | path join "*.config.toml")
    | path basename | str replace '.config.toml' '' | sort
}

def active-profile [active_link: string, default_profile: string]: nothing -> string {
  try {
    readlink $active_link | path basename | str replace '.config.toml' ''
  } catch { $default_profile }
}

def list-profiles [
  config_dir: string
  active_link: string
  default_profile: string
  --stderr
]: nothing -> nothing {
  let current = (active-profile $active_link $default_profile)
  let highlight = (if $stderr { is-terminal --stderr } else { is-terminal --stdout })

  for name in (profile-names $config_dir) {
    let line = if $name != $current {
      $"    ($name)"
    } else if $highlight {
      $"  (ansi green_bold)* ($name)(ansi reset) \(active\)"
    } else {
      $"  * ($name) \(active\)"
    }
    if $stderr {
      print -e $line
    } else {
      print $line
    }
  }
}

# Switch the active Codex auth profile, or list the available ones.
def main [
  config_dir: string
  state_dir: string
  default_profile: string
  profile?: string # profile to activate; omit to list
  --list (-l) # list profiles without switching
] {
  let active_link = ($state_dir | path join "active-profile")

  if $list or ($profile | is-empty) {
    list-profiles $config_dir $active_link $default_profile
    return
  }

  let target = ([$config_dir $"($profile).config.toml"] | path join)
  if $profile not-in (profile-names $config_dir) {
    print -e $"Unknown profile: ($profile)"
    print -e ""
    print -e "Available profiles:"
    list-profiles $config_dir $active_link $default_profile --stderr
    exit 1
  }

  mkdir $state_dir
  ln -sf $target $active_link
  print $"Switched to profile: ($profile)"
  print "Restart Codex for changes to take effect."
}
