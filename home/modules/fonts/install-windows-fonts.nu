#!/usr/bin/env nu

# ==================================================================================================
# Windows Font Install (WSL only)
# ==================================================================================================
# Copy font files from the Nix store into the Windows per-user font directory, then register each
# one under the HKCU Fonts registry key.
# ==================================================================================================

const FONT_EXTENSIONS = ["ttf" "otf" "ttc" "otc"]

const FONTS_KEY = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

def extension [file: string]: nothing -> string {
  $file | path parse | get extension | str lowercase
}

def font-files [dirs: list<string>]: nothing -> list<string> {
  $dirs
  | each {|dir| glob ($dir | path join "**" "*") }
  | flatten
  | where {|f| (extension $f) in $FONT_EXTENSIONS }
}

def font-type [file: string]: nothing -> string {
  if (extension $file) in ["otf" "otc"] { "OpenType" } else { "TrueType" }
}

def registry-document [fonts: list<string>, win_font_dir: string]: nothing -> string {
  let entries = (
    $fonts | each {|font|
      let name = ($font | path basename)
      let value = $"($font | path parse | get stem) \((font-type $font))"
      let data = ([$win_font_dir $name] | str join '\' | str replace --all '\' '\\')
      $'"($value)"="($data)"'
    }
  )
  [
    "Windows Registry Editor Version 5.00"
    ""
    $"[($FONTS_KEY)]"
    ...$entries
    ""
  ] | str join "\r\n"
}

def main [config_file: string] {
  let config = (open $config_file)
  let local_app_data = (^$config.windowsInterop LOCALAPPDATA | str trim)
  let font_dir = ([$local_app_data "Microsoft" "Windows" "Fonts"] | path join)
  mkdir $font_dir

  let results = (
    font-files $config.fontDirs | each {|font|
      let dest = ([$font_dir ($font | path basename)] | path join)
      let current = (
        if ($dest | path exists) { (ls $dest | get 0.size) } else { null }
      )
      if $current == (ls $font | get 0.size) {
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

  let win_font_dir = (^/bin/wslpath -w $font_dir | str trim)
  let registry_file = ([$font_dir ".nixos-config-fonts.reg"] | path join)

  # reg.exe detects a UTF-16LE file only from its byte-order mark.
  0x[ff fe] | save --raw --force $registry_file
  registry-document (font-files [$font_dir]) $win_font_dir
  | ^iconv --from-code UTF-8 --to-code UTF-16LE
  | save --raw --append $registry_file

  let win_registry_file = (^/bin/wslpath -w $registry_file | str trim)
  let import_result = (^/mnt/c/Windows/System32/reg.exe import $win_registry_file | complete)
  rm --force $registry_file

  if $import_result.exit_code != 0 {
    error make { msg: $"Font registration failed: ($import_result.stderr | str trim)" }
  }
  if $counts.installed > 0 {
    print "Fonts registered. Restart applications to use new fonts."
  }
}
