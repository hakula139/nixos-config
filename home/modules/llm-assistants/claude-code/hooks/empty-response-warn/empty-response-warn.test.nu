#!/usr/bin/env nu

# ==================================================================================================
# Empty Response Warning Hook Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "empty-response-warn.nu")
const EXPECTED_WARNING = "Assistant returned an empty response, likely an upstream or gateway failure."

def run-event [input: any]: nothing -> record {
  let payload = if ($input | describe) == "string" {
    $input
  } else {
    $input | to json
  }
  let run = ($payload | run-script $SCRIPT)
  assert equal $run.exit_code 0 $run.stderr
  assert equal $run.stderr ""
  $run
}

def "test non-empty assistant message stays silent" [] {
  let cases = [
    {last_assistant_message: "Done."}
    {last_assistant_message: "  ok  "}
  ]

  for case in $cases {
    let run = (run-event $case)
    assert equal $run.stdout "" ($case | to nuon)
  }
}

def "test missing or empty assistant message emits systemMessage" [] {
  let cases = [
    {stop_hook_active: false}
    {last_assistant_message: null}
    {last_assistant_message: ""}
    {last_assistant_message: "   \n\t "}
  ]

  for case in $cases {
    let run = (run-event $case)
    assert equal ($run.stdout | from json) {systemMessage: $EXPECTED_WARNING} ($case | to nuon)
  }
}

def "test malformed or non-record input exits silently" [] {
  for input in ["" "not json" "[]" "42"] {
    let run = (run-event $input)
    assert equal $run.stdout "" $input
  }
}
