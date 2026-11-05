#!/usr/bin/env nu

# ==================================================================================================
# Windows Font Install (WSL only)
# ==================================================================================================
# Copy the Nix store's fonts into the Windows per-user font directory and register each under the
# configured registry key. Windows holds the fonts it loaded at sign-in open until sign-out, so
# each copy's name carries its package's hash and a later run removes the copies it supersedes.
# ==================================================================================================

const FONT_TYPES = {ttf: "TrueType", otf: "OpenType", ttc: "TrueType", otc: "OpenType"}

def main [
  --config: path # Wrapper-supplied JSON with the font directories, registry key, and interop helper
] {
  let config = (open $config)
  let local_app_data = (^$config.windowsInterop LOCALAPPDATA | str trim)
  let font_dir = ([$local_app_data "Microsoft/Windows/Fonts"] | path join)
  mkdir $font_dir

  let fonts = (
    $config.fontDirs
    | each {|dir|
      let hash = (^nix-store --query --hash $dir | str substring 7..14)
      glob ($dir | path join "**/*")
      | each {|path| {path: $path, hash: $hash, ...($path | path parse)} }
    }
    | flatten
    | insert type {|font| $FONT_TYPES | get -o ($font.extension | str lowercase) }
    | where type != null
    | insert name {|font| $"($font.stem).($font.hash).($font.extension)" }
    | insert status {|font|
      let target = ([$font_dir $font.name] | path join)
      let partial = $"($target).part"
      if ($target | path exists) {
        "skipped"
      } else {
        try {
          ^cp --force $font.path $partial
          mv $partial $target
          "installed"
        } catch {
          rm --force $partial
          "failed"
        }
      }
    }
  )

  let counts = {
    installed: ($fonts | where status == "installed" | length)
    skipped: ($fonts | where status == "skipped" | length)
    failed: ($fonts | where status == "failed" | length)
  }

  print $"Fonts: ($counts.installed) installed, ($counts.skipped) already present, ($counts.failed) failed"

  let present = ($fonts | where status != "failed")
  let win_font_dir = (^/bin/wslpath -w $font_dir | str trim)
  let entries = (
    $present
    | insert data {|font| [$win_font_dir $font.name] | str join '\' | str replace --all '\' '\\' }
    | format pattern '"{stem} ({type})"="{data}"'
  )

  let registry_file = ([$font_dir ".nixos-config-fonts.reg"] | path join)
  (
    [
      # reg.exe detects a UTF-16LE file only from its byte-order mark.
      "\u{feff}Windows Registry Editor Version 5.00"
      ""
      $"[($config.fontsKey)]"
      ...$entries
      ""
    ]
    | str join "\r\n"
    | ^iconv
      --from-code UTF-8
      --to-code UTF-16LE
    | save --raw --force $registry_file
  )

  let win_registry_file = (^/bin/wslpath -w $registry_file | str trim)
  let import_result = (^/mnt/c/Windows/System32/reg.exe import $win_registry_file | complete)
  rm --force $registry_file

  if $import_result.exit_code != 0 {
    error make {msg: $"Font registration failed: ($import_result.stderr | str trim)"}
  }

  let store_names = ($present.path | path basename)
  let superseded = (
    ls --short-names $font_dir
    | get name
    # A nix-base32 hash infix before the extension
    | where ($it | str replace --regex '\.[0-9a-df-np-sv-z]{8}(\.[^.]+)$' "$1") in $store_names
    | where $it not-in $present.name
    | each {|name| [$font_dir $name] | path join }
  )

  for file in $superseded { try { rm $file } }

  if $counts.installed > 0 {
    print "New fonts load in applications started after the next Windows sign-in."
  }
}
