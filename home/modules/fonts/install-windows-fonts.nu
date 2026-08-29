#!/usr/bin/env nu

# ==============================================================================
# Windows Font Install (WSL only)
# ==============================================================================
# Copy font files from the Nix store into the Windows per-user font directory
# and register them in the HKCU registry.
# ==============================================================================

const FONT_EXTENSIONS = [ttf otf ttc otc]

def extension [file: string]: nothing -> string {
  $file | path parse | get extension | str downcase
}

def font-files [dirs: list<string>]: nothing -> list<string> {
  $dirs
  | each {|dir| glob ($dir | path join "**" "*") }
  | flatten
  | where {|f| (extension $f) in $FONT_EXTENSIONS }
}

def font-type [file: string]: nothing -> string {
  if (extension $file) in [otf otc] { "OpenType" } else { "TrueType" }
}

def main [config_file: string] {
  let config = (open $config_file)
  let local_app_data = (^$config.windowsInterop LOCALAPPDATA | str trim)
  let font_dir = ([$local_app_data "Microsoft" "Windows" "Fonts"] | path join)
  mkdir $font_dir

  let results = (
    font-files $config.fontDirs | each {|font|
      let dest = ([$font_dir ($font | path basename)] | path join)
      if ($dest | path exists) {
        "skipped"
      } else {
        try {
          cp --force $font $dest
          "installed"
        } catch { "failed" }
      }
    }
  )

  let counts = {
    installed: ($results | where $it == "installed" | length)
    skipped: ($results | where $it == "skipped" | length)
    failed: ($results | where $it == "failed" | length)
  }
  print $"Fonts: ($counts.installed) installed, ($counts.skipped) already present, ($counts.failed) failed"

  if $counts.installed == 0 {
    return
  }

  let win_font_dir = (^wslpath -w $font_dir | str trim)
  for font in (font-files [$font_dir]) {
    let name = ($font | path basename)
    let value = $"($font | path parse | get stem) \((font-type $font)\)"
    (
      ^/mnt/c/Windows/System32/reg.exe add "HKCU\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts"
        /v $value /t REG_SZ /d $"($win_font_dir)\\($name)" /f
      | complete
      | ignore
    )
  }
  print "Fonts registered. Restart applications to use new fonts."
}
