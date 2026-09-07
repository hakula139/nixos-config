#!/usr/bin/env nu

# ==============================================================================
# Claude Code Auth Profile Switcher
# ==============================================================================

# `glob` rather than `ls`, which raises when no profile has been written yet.
def profile-names [profiles_dir: string]: nothing -> list<string> {
  glob ($profiles_dir | path join "*.sh") | path parse | get stem | sort
}

def active-profile [active_link: string]: nothing -> string {
  try { readlink $active_link | path parse | get stem } catch { "" }
}

def list-profiles [profiles_dir: string, active_link: string, --stderr]: nothing -> nothing {
  let current = (active-profile $active_link)
  let highlight = (if $stderr { is-terminal --stderr } else { is-terminal --stdout })

  for name in (profile-names $profiles_dir) {
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

# Switch the active Claude Code auth profile, or list the available ones.
def main [
  state_dir: string
  profile?: string # profile to activate; omit to list
  --list (-l) # list profiles without switching
] {
  let profiles_dir = ($state_dir | path join "profiles")
  let active_link = ($state_dir | path join "active-profile")

  if $list or ($profile | is-empty) {
    list-profiles $profiles_dir $active_link
    return
  }

  let target = ([$profiles_dir $"($profile).sh"] | path join)
  if not ($target | path exists) {
    print -e $"Unknown profile: ($profile)"
    print -e ""
    print -e "Available profiles:"
    list-profiles $profiles_dir $active_link --stderr
    exit 1
  }

  ln -sf $target $active_link
  print $"Switched to profile: ($profile)"
  print "Restart Claude Code for changes to take effect."
}
