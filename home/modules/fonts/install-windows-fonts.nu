#!/usr/bin/env nu

# ==============================================================================
# Windows Font Install (WSL only)
# ==============================================================================
# Copy font files from the Nix store into the Windows per-user font directory
# and register them in the HKCU registry.
# ==============================================================================

use @windowsInterop@ *

const FONT_EXTENSIONS = [ttf otf ttc otc]
const FONT_DIRS = @fontDirs@

def font-files [dirs: list<string>]: nothing -> list<string> {
  $dirs
  | each {|dir| glob ($dir | path join "**" "*") }
  | flatten
  | where {|f| ($f | path parse | get extension | str downcase) in $FONT_EXTENSIONS }
}

def font-type [file: string]: nothing -> string {
  if ($file | path parse | get extension | str downcase) in [otf otc] { "OpenType" } else { "TrueType" }
}

def main [] {
  let font_dir = ([(windows-env-path LOCALAPPDATA) "Microsoft" "Windows" "Fonts"] | path join)
  mkdir $font_dir

  let results = (
    font-files $FONT_DIRS | each {|font|
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

  let counts = ($results | uniq --count | transpose -i -r -d)
  let installed = ($counts | get -o installed | default 0)
  print $"Fonts: ($installed) installed, ($counts | get -o skipped | default 0) already present, ($counts | get -o failed | default 0) failed"

  if $installed == 0 { return }

  let win_font_dir = (^wslpath -w $font_dir | str trim)
  for font in (font-files [$font_dir]) {
    let name = ($font | path basename)
    let value = $"($font | path parse | get stem) \((font-type $font)\)"
    (
      ^reg.exe add "HKCU\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts"
        /v $value /t REG_SZ /d $"($win_font_dir)\\($name)" /f
      | complete
      | ignore
    )
  }
  print "Fonts registered. Restart applications to use new fonts."
}
