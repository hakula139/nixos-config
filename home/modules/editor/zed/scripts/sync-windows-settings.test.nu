#!/usr/bin/env nu

# ==================================================================================================
# Windows Zed Settings Sync Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "sync-windows-settings.nu")

def setup-fixture []: nothing -> record {
  let dir = (mktemp --directory)
  let app_data = ($dir | path join "AppData/Roaming")
  let interop = ($dir | path join "windows-interop")
  let settings_src = ($dir | path join "settings.json")
  let keymap_src = ($dir | path join "keymap.json")
  let config = ($dir | path join "config.json")

  $"#!/bin/sh\nprintf '%s\n' '($app_data)'\n" | save $interop
  ^chmod +x $interop

  ({buffer_font_size: 15} | to json --indent 2) | save $settings_src
  [
    {
      context: "Workspace"
      bindings: {"ctrl-=": "pane::GoForward"}
    }
  ]
  | to json --indent 2
  | save $keymap_src

  {
    settingsFile: $settings_src
    keymapFile: $keymap_src
    windowsInterop: $interop
  }
  | to json
  | save $config

  {
    app_data: $app_data
    config: $config
    settings_src: $settings_src
    keymap_src: $keymap_src
  }
}

def "test initial sync writes settings and keymap atomically" [] {
  let fixture = (setup-fixture)
  let target_dir = ($fixture.app_data | path join "Zed")
  let settings_target = ($target_dir | path join "settings.json")
  let keymap_target = ($target_dir | path join "keymap.json")

  let run = (run-script $SCRIPT --config $fixture.config)

  assert equal $run {
    stdout: $"Zed settings: synced to ($settings_target)\nZed keymap: synced to ($keymap_target)\n"
    stderr: ""
    exit_code: 0
  }
  assert equal (open --raw $settings_target) (open --raw $fixture.settings_src)
  assert equal (open --raw $keymap_target) (open --raw $fixture.keymap_src)
}

def "test second sync with identical files is a no-op" [] {
  let fixture = (setup-fixture)
  let _ = (run-script $SCRIPT --config $fixture.config)

  let run = (run-script $SCRIPT --config $fixture.config)

  assert equal $run {
    stdout: "Zed settings: unchanged\nZed keymap: unchanged\n"
    stderr: ""
    exit_code: 0
  }
}

def "test sync updates only files whose content changed" [] {
  let fixture = (setup-fixture)
  let target_dir = ($fixture.app_data | path join "Zed")
  let settings_target = ($target_dir | path join "settings.json")
  let _ = (run-script $SCRIPT --config $fixture.config)

  "{}" | save --force $settings_target
  let run = (run-script $SCRIPT --config $fixture.config)

  assert equal $run {
    stdout: $"Zed settings: synced to ($settings_target)\nZed keymap: unchanged\n"
    stderr: ""
    exit_code: 0
  }
  assert equal (open --raw $settings_target) (open --raw $fixture.settings_src)
}
