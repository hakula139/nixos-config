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

def list-profiles [] {
  let current = (active-profile)
  # `ansi` emits escapes even when redirected, so colour is gated by hand.
  let highlight = (is-terminal --stdout)

  for name in $PROFILE_NAMES {
    if $name != $current {
      print $"    ($name)"
    } else if $highlight {
      print $"  (ansi green_bold)* ($name)(ansi reset) \(active\)"
    } else {
      print $"  * ($name) \(active\)"
    }
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
    list-profiles
    exit 1
  }

  ln -sf $target $ACTIVE_LINK
  print $"Switched to profile: ($profile)"
  print "Restart Claude Code for changes to take effect."
}
