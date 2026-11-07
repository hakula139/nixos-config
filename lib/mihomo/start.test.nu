#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Start Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "start.nu")

def "test mihomo replaces the start process unless a failed update finds no config" [] {
  let cases = [
    [name update_status config status];
    ["update succeeds with a config" 0 true 0]
    ["update fails with a config" 1 true 0]
    ["update fails without a config" 1 false 1]
  ]

  for case in $cases {
    let dir = (mktemp --directory)
    let config_dir = ($dir | path join "mihomo")
    let log = ($dir | path join "calls.jsonl")
    mkdir $config_dir
    touch $log
    if $case.config {
      "mixed-port: 7890\n" | save ($config_dir | path join "config.yaml")
    }

    let run = with-env {
      PATH: [$env.NU_TEST_STUBS]
      STUB_LOG: $log
      STUB_UPDATE_STATUS: ($case.update_status | into string)
    } {
      (
        ^$nu.current-exe --no-config-file
          $SCRIPT --config-dir $config_dir
        | complete
      )
    }
    let context = $"($case.name): ($run.stderr)"
    assert equal $run.exit_code $case.status $context

    # Only an exec leaves mihomo a direct child of this test process.
    let expected = if $case.status == 0 { [{args: [-d $config_dir], ppid: $nu.pid}] } else { [] }
    assert equal (open $log | from json --objects) $expected $context
  }
}
