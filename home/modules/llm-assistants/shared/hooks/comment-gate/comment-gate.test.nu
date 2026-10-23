#!/usr/bin/env nu

# ==================================================================================================
# Comment Gate Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join comment-gate.nu)

# The context the hook hands the agent, or null when it stays silent.
def gate [env_vars: record]: nothing -> any {
  let dir = (mktemp --directory)
  let config_file = ($dir | path join config.json)

  let model_call = ($env.NU_TEST_STUBS | path join model-call)
  {modelCall: $model_call, model: stub, prompt: "", patchInput: ""} | to json | save $config_file

  let payload = {
    tool_name: Write
    tool_input: {
      file_path: "/repo/load.py"
      content: (
        "
        def load(path):
            # Open the file and read it
            return open(path).read()

        "
        | str dedent
      )
    }
  }

  let run = with-env $env_vars {
    $payload | to json | ^$nu.current-exe --no-config-file $SCRIPT $config_file | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  if ($run.stdout | str trim | is-empty) {
    null
  } else {
    $run.stdout | from json | get hookSpecificOutput.additionalContext
  }
}

def "test a passing verdict stays silent" [] {
  let context = (gate {STUB_REPLY: "ok: true"})

  assert equal $context null
}

def "test a failing verdict hands the findings to the agent" [] {
  let reply = (
    "
    - Quote: `# Open the file and read it`

    ok: false
    "
    | str dedent
  )

  let context = (gate {STUB_REPLY: $reply})

  assert equal $context (
    "
    The comment gate flagged comments in the text you just wrote.
    Check each finding against surrounding code and comparable files before changing it.

    - Quote: `# Open the file and read it`
    ok: false
    "
    | str dedent
  )
}

def "test a call without a verdict tells the agent why the text went unchecked" [] {
  let timeout = "model-call: curl: (28) Connection timed out"
  let cases = [
    [env_vars reason];
    [{STUB_ERROR: $timeout} $timeout]
    [{STUB_REPLY: "The comment looks fine."} "the model's reply carries no verdict"]
  ]

  for case in $cases {
    let context = (gate $case.env_vars)

    assert equal $context (
      $"
      The comment gate could not check the text you just wrote, so its comments went unreviewed.
      Reason: ($case.reason)
      "
      | str dedent
    ) ($case.env_vars | to nuon)
  }
}
