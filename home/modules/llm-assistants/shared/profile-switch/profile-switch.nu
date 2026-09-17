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

def write-config [config: record, profile: path] {
  let current = if ($config.configFile | path exists) { open $config.configFile } else { {} }
  let reset_paths = ($config.resetKeys | each { split row "." | into cell-path })
  let settings = ($config.defaultSettings
    | merge deep --strategy overwrite $current
    | reject --optional ...$reset_paths
    | merge deep --strategy overwrite (open $profile))
  let serialized = match ($config.configFile | path parse | get extension) {
    "toml" => { $settings | to toml }
    "yml" | "yaml" => { $settings | to yaml }
  }
  let directory = ($config.configFile | path dirname)
  mkdir $directory
  let temporary = (^mktemp $"--tmpdir=($directory)" '.profile-config.XXXXXXXXXX' | str trim)

  try {
    $serialized | save --force $temporary
    ^chmod 600 $temporary
    ^mv --force $temporary $config.configFile
  } catch {|error|
    rm --force $temporary
    error make $error
  }
}

# Switch the active auth profile, or list the available ones.
def main [
  config_file: string
  profile?: string # profile to activate; omit to list
  --list (-l) # list profiles without switching
  --initialize # retain an installed profile or select the configured default
] {
  let config = (open $config_file)
  let active_link = ($config.stateDir | path join "active-profile")

  let profile = if $initialize {
    let current = (active-profile $config $active_link)
    let available = (profile-names $config)
    if $current in $available {
      $current
    } else {
      $config.defaultProfile
    }
  } else { $profile }

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

  if $config.configFile != null {
    write-config $config $target
  }
  mkdir $config.stateDir
  ln -sf $target $active_link
  if not $initialize {
    print $"Switched to profile: ($profile)"
    print $"Restart ($config.assistant) for changes to take effect."
  }
}
