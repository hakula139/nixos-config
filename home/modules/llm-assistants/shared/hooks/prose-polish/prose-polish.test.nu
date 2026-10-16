#!/usr/bin/env nu

# ==================================================================================================
# Prose Polish Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join prose-polish.nu)
const STUB = ($SCRIPT_DIR | path join model-call.stub.nu)

const PARAGRAPH = "Run `nix flake check` before you push, since it utilizes the same hooks as CI does."
const POLISHED = "Run `nix flake check` before you push, since it uses the same hooks as CI does."

const SIMPLIFY = {find: utilizes, replace: uses}
const DROP_CODE = {find: "`nix flake check`", replace: "the flake check"}
const ADD_SEMICOLON = {find: " since ", replace: "; "}

# `input` is the hook's rewritten tool input, or null when it leaves the call alone, and `calls`
# holds the passages each model call received.
def polish [payload: record, rules: list<record>]: nothing -> record {
  let dir = (mktemp --directory)
  let stub = ($dir | path join model-call)
  let rules_file = ($dir | path join rules.json)
  let config_file = ($dir | path join config.json)
  let log = ($dir | path join calls.jsonl)

  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $STUB) | save $stub
  ^chmod +x $stub
  $rules | to json | save $rules_file
  {
    maxRepairs: 1
    mcpProseFields: {}
    model: stub
    modelCall: $stub
    phrasing: ""
    prompt: ""
    repairPrompt: ""
  }
  | to json
  | save $config_file

  let env_vars = {PROSE_POLISH_ENABLED: "true", STUB_LOG: $log, STUB_RULES: $rules_file}
  let run = with-env $env_vars {
    $payload
    | upsert cwd $dir
    | to json
    | ^$nu.current-exe --no-config-file $SCRIPT $config_file
    | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  let calls = if ($log | path exists) { open $log | lines | each { from json } } else { [] }
  let input = if ($run.stdout | str trim | is-empty) {
    null
  } else {
    $run.stdout | from json | get hookSpecificOutput.updatedInput
  }
  {input: $input, calls: $calls}
}

def write [path: string, content: string]: nothing -> record {
  {tool_name: Write, tool_input: {file_path: $path, content: $content}}
}

def "test a write rewrites only its prose and keeps everything else byte-identical" [] {
  # The fence's middle piece holds no delimiter, so only fence tracking keeps it out of the rewrite.
  let document = $"
    ---
    title: Notes that utilizes front matter
    ---

    # Checks

      ($PARAGRAPH)

    ```text
    head

    This line utilizes enough words to pass for prose, yet it sits inside a fence.

    tail
    ```


    - A list item that also utilizes enough words to count as prose.

    " | str dedent

  let expected = $"
    ---
    title: Notes that utilizes front matter
    ---

    # Checks

      ($POLISHED)

    ```text
    head

    This line utilizes enough words to pass for prose, yet it sits inside a fence.

    tail
    ```


    - A list item that also uses enough words to count as prose.

    " | str dedent

  let result = (polish (write notes.md $document) [$SIMPLIFY])

  assert equal ($result.calls.0 | get text) [
    $PARAGRAPH
    "- A list item that also utilizes enough words to count as prose."
  ]
  assert equal $result.input.content $expected
}

def "test an edit leaves paragraphs the document already holds" [] {
  let dir = (mktemp --directory)
  let existing = "This paragraph already utilizes the document, so the agent did not write it."

  $"
    # Notes

    ($existing)

    " | str dedent | save ($dir | path join notes.md)

  let payload = {
    tool_name: Edit
    tool_input: {
      file_path: ($dir | path join notes.md)
      old_string: $existing
      new_string: ($"
        ($existing)

        ($PARAGRAPH)
        " | str dedent)
    }
  }

  let result = (polish $payload [$SIMPLIFY])

  assert equal ($result.calls | flatten | get text) [$PARAGRAPH]
  assert equal $result.input.new_string ($"
    ($existing)

    ($POLISHED)
    " | str dedent)
}

def "test a rewrite that drops a code span is repaired with the reason" [] {
  let result = (polish (write notes.md $PARAGRAPH) [$DROP_CODE $SIMPLIFY])

  let repair = ($result.calls | get 1.0)
  assert equal $repair.rejected ($PARAGRAPH | str replace $DROP_CODE.find $DROP_CODE.replace)
  assert str contains $repair.problem "code span"
  assert equal $result.input.content $POLISHED
}

def "test a rewrite that stays faulty keeps the agent text" [] {
  let result = (polish (write notes.md $PARAGRAPH) [$DROP_CODE $ADD_SEMICOLON])

  assert equal ($result.calls | length) 2
  assert equal $result.input null
}
