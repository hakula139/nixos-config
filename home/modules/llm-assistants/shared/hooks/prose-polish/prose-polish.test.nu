#!/usr/bin/env nu

# ==================================================================================================
# Prose Polish Tests
# ==================================================================================================
# A stub stands in for the model. Each call applies the next queued replacement to every passage
# and records the passages it was sent, so a test controls the rewrite and inspects what was asked.
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join prose-polish.nu)

const STUB = '
def main [] {
  let request = (^cat | from json)
  let passages = ($request.user | lines | last | from json | get passages)
  let calls = ($env.STUB_LOG | path exists | if $in { open $env.STUB_LOG | lines | length } else { 0 })
  $passages | to json --raw | $"($in)\n" | save --append $env.STUB_LOG
  let rule = (open $env.STUB_RULES | get $calls)
  {
    passages: ($passages | each {|p| {id: $p.id, text: ($p.text | str replace --all $rule.find $rule.replace)} })
  }
  | to json
}
'

const PARAGRAPH = "Run `nix flake check` before you push, since it utilizes the same hooks as CI does."
const POLISHED = "Run `nix flake check` before you push, since it uses the same hooks as CI does."

# Run the hook on `payload` with the stub applying `rules` in turn. Returns the hook's rewritten tool
# input, or null when it leaves the call alone, along with the passages each model call received.
def polish [payload: record, rules: list<record>]: nothing -> record {
  let dir = (mktemp --directory)
  let stub = ($dir | path join stub.nu)
  $"#!($nu.current-exe) --no-config-file\n($STUB)" | save $stub
  ^chmod +x $stub
  $rules | to json | save ($dir | path join rules.json)
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
  | save ($dir | path join config.json)

  let log = ($dir | path join calls.jsonl)
  let env_vars = {PROSE_POLISH_ENABLED: "true", STUB_LOG: $log, STUB_RULES: ($dir | path join rules.json)}
  let run = with-env $env_vars {
    $payload | upsert cwd $dir | to json
    | ^$nu.current-exe --no-config-file $SCRIPT ($dir | path join config.json)
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
  # The middle piece holds no delimiter, so only fence tracking keeps it out of the rewrite.
  let fence = [
    "```text"
    "head"
    ""
    "This line utilizes enough words to pass for prose, yet it sits inside a fence."
    ""
    "tail"
    "```"
  ]
  let document = [
    "---"
    "title: Notes that utilizes front matter"
    "---"
    ""
    "# Checks"
    ""
    $"  ($PARAGRAPH)"
    ""
    ...$fence
    ""
    ""
    "- A list item that also utilizes enough words to count as prose."
    ""
  ]
  let result = (polish (write notes.md ($document | str join "\n")) [{find: utilizes, replace: uses}])

  assert equal ($result.calls.0 | get text) [
    $PARAGRAPH
    "- A list item that also utilizes enough words to count as prose."
  ]
  let expected = (
    $document
    | each { str replace "- A list item that also utilizes" "- A list item that also uses" }
    | each { str replace $PARAGRAPH $POLISHED }
  )
  assert equal $result.input.content ($expected | str join "\n")
}

def "test a rewrite keeps the line endings of the piece it replaces" [] {
  let document = "# Checks\r\n\r\nRun `nix flake check` before you push,\r\nsince it utilizes the same hooks as CI.\r\n"
  let result = (polish (write notes.md $document) [{find: utilizes, replace: uses}])
  assert equal $result.input.content (
    "# Checks\r\n\r\nRun `nix flake check` before you push,\r\nsince it uses the same hooks as CI.\r\n"
  )
}

def "test an edit leaves paragraphs the document already holds" [] {
  let dir = (mktemp --directory)
  let existing = "This paragraph already utilizes the document, so the agent did not write it."
  $"# Notes\n\n($existing)\n" | save ($dir | path join notes.md)

  let payload = {
    tool_name: Edit
    tool_input: {
      file_path: ($dir | path join notes.md)
      old_string: $existing
      new_string: $"($existing)\n\n($PARAGRAPH)"
    }
  }
  let result = (polish $payload [{find: utilizes, replace: uses}])

  assert equal ($result.calls | flatten | get text) [$PARAGRAPH]
  assert equal $result.input.new_string $"($existing)\n\n($POLISHED)"
}

def "test a rewrite that drops a code span is repaired with the reason" [] {
  let rules = [
    {find: "`nix flake check`", replace: "the flake check"}
    {find: utilizes, replace: uses}
  ]
  let result = (polish (write notes.md $PARAGRAPH) $rules)

  let repair = ($result.calls | get 1.0)
  assert equal $repair.rejected ($PARAGRAPH | str replace "`nix flake check`" "the flake check")
  assert str contains $repair.problem "code span"
  assert equal $result.input.content $POLISHED
}

def "test a rewrite that stays faulty keeps the agent text" [] {
  let rules = [
    {find: "`nix flake check`", replace: "the flake check"}
    {find: " since ", replace: "; "}
  ]
  let result = (polish (write notes.md $PARAGRAPH) $rules)

  assert equal ($result.calls | length) 2
  assert equal $result.input null
}
