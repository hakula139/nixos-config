#!/usr/bin/env nu

# ==================================================================================================
# Config File Helper Tests
# ==================================================================================================

use std/assert
use ./config-file.nu [open-record save-atomic]

def "test open-record reads a record" [] {
  let dir = (mktemp --directory)
  let path = ($dir | path join "settings.json")
  {a: {b: 1}}
  | to json
  | save $path

  assert equal (open-record $path) {a: {b: 1}}
}

def "test open-record falls back to an empty record" [] {
  let dir = (mktemp --directory)
  let empty = ($dir | path join "empty.json")
  let list = ($dir | path join "list.json")
  "" | save $empty
  [1 2]
  | to json
  | save $list

  assert equal (open-record ($dir | path join "missing.json")) {}
  assert equal (open-record $empty) {}
  assert equal (open-record $list) {}
}

def "test save-atomic replaces content and leaves no temporary file" [] {
  let dir = (mktemp --directory)
  let target = ($dir | path join "config.toml")
  "old" | save $target

  save-atomic "new = 1\n" $target

  assert equal (open --raw $target) "new = 1\n"
  assert equal (ls --all $dir | get name | path basename) ["config.toml"]
}

def "test save-atomic creates a missing target" [] {
  let dir = (mktemp --directory)
  let target = ($dir | path join "created.json")

  save-atomic "{}" $target

  assert equal (open --raw $target) "{}"
}

def "test save-atomic removes the temporary file when the replace fails" [] {
  let dir = (mktemp --directory)
  let bin = ($dir | path join "bin")
  let target_dir = ($dir | path join "target")
  mkdir $bin $target_dir
  "#!/bin/sh\nexit 1\n" | save ($bin | path join "mv")
  chmod +x ($bin | path join "mv")
  let target = ($target_dir | path join "config.json")
  "old" | save $target

  let failed = with-env {PATH: ($env.PATH | prepend $bin)} {
    try {
      save-atomic "new" $target
      false
    } catch {
      true
    }
  }

  assert $failed
  assert equal (open --raw $target) "old"
  assert equal (ls --all $target_dir | get name | path basename) ["config.json"]
}
