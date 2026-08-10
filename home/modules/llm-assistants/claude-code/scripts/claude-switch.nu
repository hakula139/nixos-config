#!/usr/bin/env nu

# ==============================================================================
# Claude Code Auth Profile Switcher
# ==============================================================================
# List and switch between authentication profiles by updating the active-profile
# symlink in the state directory.
# ==============================================================================

const PROFILES_DIR = "@stateDir@/profiles"
const ACTIVE_LINK = "@stateDir@/active-profile"
const PROFILE_NAMES = @profileNames@

def active-profile []: nothing -> string {
  try { readlink $ACTIVE_LINK | path parse | get stem } catch { "" }
}

def list-profiles [--stderr]: nothing -> nothing {
  let current = (active-profile)
  # `ansi` emits escapes even when redirected, so colour is gated by hand.
  let highlight = (if $stderr { is-terminal --stderr } else { is-terminal --stdout })

  for name in $PROFILE_NAMES {
    let line = if $name != $current {
      $"    ($name)"
    } else if $highlight {
      $"  (ansi green_bold)* ($name)(ansi reset) \(active\)"
    } else {
      $"  * ($name) \(active\)"
    }
    if $stderr { print -e $line } else { print $line }
  }
}

# Switch the active Claude Code auth profile, or list the available ones.
def main [
  profile?: string # profile to activate; omit to list
  --list (-l) # list profiles without switching
] {
  if $list or ($profile | is-empty) {
    list-profiles
    return
  }

  let target = ([$PROFILES_DIR $"($profile).sh"] | path join)
  if not ($target | path exists) {
    print -e $"Unknown profile: ($profile)"
    print -e ""
    print -e "Available profiles:"
    list-profiles --stderr
    exit 1
  }

  ln -sf $target $ACTIVE_LINK
  print $"Switched to profile: ($profile)"
  print "Restart Claude Code for changes to take effect."
}
