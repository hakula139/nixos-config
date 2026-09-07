#!/usr/bin/env nu

# ==============================================================================
# Auth Profile Switcher
# ==============================================================================

# `glob` rather than `ls`, which raises when no profile has been written yet.
def profile-names [config: record]: nothing -> list<string> {
  glob ($config.profilesDir | path join $"*.($config.extension)")
    | path parse --extension $config.extension | get stem | sort
}

def active-profile [config: record, active_link: string]: nothing -> string {
  try {
    readlink $active_link | path parse --extension $config.extension | get stem
  } catch { "" }
}

def list-profiles [config: record, active_link: string, --stderr]: nothing -> nothing {
  let current = (active-profile $config $active_link)
  let highlight = (if $stderr { is-terminal --stderr } else { is-terminal --stdout })

  for name in (profile-names $config) {
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

# Switch the active auth profile, or list the available ones.
def main [
  config_file: string
  profile?: string # profile to activate; omit to list
  --list (-l) # list profiles without switching
] {
  let config = (open $config_file)
  let active_link = ($config.stateDir | path join "active-profile")

  if $list or ($profile | is-empty) {
    list-profiles $config $active_link
    return
  }

  let target = ([$config.profilesDir $"($profile).($config.extension)"] | path join)
  if $profile not-in (profile-names $config) {
    print -e $"Unknown profile: ($profile)"
    print -e ""
    print -e "Available profiles:"
    list-profiles $config $active_link --stderr
    exit 1
  }

  ln -sf $target $active_link
  print $"Switched to profile: ($profile)"
  print $"Restart ($config.assistant) for changes to take effect."
}
