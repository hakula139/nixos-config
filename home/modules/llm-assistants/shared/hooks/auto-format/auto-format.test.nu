#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Hook Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const PATCH_INPUT = ($SCRIPT_DIR | path join .. lib patch-input patch-input.nu)

def run-event [
  input: any
  cwd: string
  --reports: list<string> = []
  --exit-code: int = 0
  --stderr: string = ""
]: nothing -> record {
  let dir = (mktemp --directory)
  let bin = ($dir | path join bin)
  let log = ($dir | path join calls.jsonl)
  let config_file = ($dir | path join config.json)
  let parser = ($bin | path join patch-input)

  mkdir $bin
  ^ln -s (which cat | get 0.path) ($bin | path join cat)
  open --raw $PATCH_INPUT
  | str replace --regex '^#!.*' $"#!($nu.current-exe) --no-config-file"
  | save $parser
  ^chmod +x $parser
  {fileFormatter: ($env.NU_TEST_STUBS | path join file-formatter), patchInput: $parser}
  | to json
  | save $config_file

  let payload = if ($input | describe) == "string" {
    $input
  } else {
    $input | upsert cwd $cwd | to json
  }
  let run = with-env {
    PATH: $bin
    STUB_LOG: $log
    STUB_REPORTS: ($reports | to json --raw)
    STUB_EXIT: $exit_code
    STUB_STDERR: $stderr
  } {
    $payload | ^$nu.current-exe --no-config-file $SCRIPT $config_file | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  {
    calls: (if ($log | path exists) { open $log | from json --objects } else { [] })
    run: $run
  }
}

def "test edits forward paths and checks once from event cwd" [] {
  let cases = [
    {
      input: {tool_name: Write, tool_input: {file_path: notes.md}}
      paths: [notes.md]
    }
    {
      input: {
        tool_name: apply_patch
        tool_input: {
          command: ([
            "*** Begin Patch"
            "*** Update File: --notes.md"
            "*** Update File: ./notes.md"
            "*** Add File: added.md"
            "*** Delete File: deleted.md"
            "*** End Patch"
          ] | str join "\n")
        }
      }
      paths: [./--notes.md ./notes.md added.md]
    }
    {
      input: {
        tool_name: apply_patch
        tool_input: {command: "*** Begin Patch\n*** Delete File: deleted.md\n*** End Patch"}
      }
      paths: []
    }
  ]

  for case in $cases {
    let cwd = (mktemp --directory | path expand)

    let result = (run-event $case.input $cwd)

    let expected = if ($case.paths | is-empty) {
      []
    } else {
      [{cwd: $cwd, args: [--checks ...$case.paths]}]
    }
    assert equal $result.calls $expected ($case | to nuon)
    assert equal $result.run.stdout ""
  }
}

def "test failed formatter diagnostics reach the hook response" [] {
  let cwd = (mktemp --directory | path expand)
  let input = {tool_name: Edit, tool_input: {file_path: notes.md}}
  let reports = ["first problem" "second problem"]

  let result = (run-event $input $cwd --reports $reports --exit-code 7 --stderr "formatter warning")

  assert equal $result.calls [{cwd: $cwd, args: [--checks notes.md]}]
  assert equal ($result.run.stdout | from json) {
    hookSpecificOutput: {
      hookEventName: PostToolUse
      additionalContext: (
        ["Formatters and linters reported problems in the edited files." ...$reports]
        | str join "\n\n"
      )
    }
  }
  assert equal $result.run.stderr "formatter warning\n"
}

def "test malformed input exits cleanly without calling the formatter" [] {
  for input in ["not json" {tool_name: Write, tool_input: {}}] {
    let cwd = (mktemp --directory | path expand)

    let result = (run-event $input $cwd)

    assert equal [$result.run.stdout $result.calls] ["" []] ($input | to nuon)
  }
}
