#!/usr/bin/env nu

# ==================================================================================================
# Prose Polish Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join prose-polish.nu)

const PARAGRAPH = "推送之前先运行 `nix flake check`，它会用与 CI 相同的钩子进行检查。"
const POLISHED = "推送之前先运行 `nix flake check`，它会用与 CI 相同的钩子检查。"

const SIMPLIFY = {find: 进行检查, replace: 检查}
const DROP_CODE = {find: "`nix flake check`", replace: "这项检查"}
const ADD_SEMICOLON = {find: "，", replace: "; "}

# `input` is the hook's rewritten tool input, or null when it leaves the call alone, and `calls`
# holds the passages each model call received. `session` adds environment variables to the hook's,
# which never inherits the caller's `DISABLE_PROSE_POLISH`.
def polish [payload: record, rules: list<record>, session: record = {}]: nothing -> record {
  let dir = (mktemp --directory)
  let rules_file = ($dir | path join rules.json)
  let config_file = ($dir | path join config.json)
  let log = ($dir | path join calls.jsonl)

  $rules | to json | save $rules_file
  {
    modelCall: ($env.NU_TEST_STUBS | path join model-call)
    model: stub
    phrasing: ""
    prompt: ""
    repairPrompt: ""
    maxRepairs: 1
    mcpProseFields: {}
  }
  | to json
  | save $config_file

  hide-env --ignore-errors DISABLE_PROSE_POLISH
  let env_vars = ($session | merge {STUB_LOG: $log, STUB_RULES: $rules_file})
  let run = with-env $env_vars {
    $payload
    | upsert cwd $dir
    | to json
    | ^$nu.current-exe --no-config-file $SCRIPT $config_file
    | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  let calls = if ($log | path exists) { open $log | from json --objects } else { [] }
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
  let document = (
    $"
    ---
    title: 带有前置元数据并且需要进行检查的笔记
    ---

    # Checks

      ($PARAGRAPH)

    ```text
    head

    这一行的汉字足以算作正文，但它位于代码块中，不应进行检查。

    tail
    ```


    - 这个列表项同样含有足够的汉字，也需要进行检查。

    "
    | str dedent
  )

  let expected = (
    $"
    ---
    title: 带有前置元数据并且需要进行检查的笔记
    ---

    # Checks

      ($POLISHED)

    ```text
    head

    这一行的汉字足以算作正文，但它位于代码块中，不应进行检查。

    tail
    ```


    - 这个列表项同样含有足够的汉字，也需要检查。

    "
    | str dedent
  )

  let result = (polish (write notes.md $document) [$SIMPLIFY])

  assert equal ($result.calls | flatten | get text) [
    $PARAGRAPH
    "- 这个列表项同样含有足够的汉字，也需要进行检查。"
  ]
  assert equal $result.input.content $expected
}

def "test an edit leaves paragraphs the document already holds" [] {
  let dir = (mktemp --directory)
  let existing = "这一段早已在文档里，并非智能体所写，因此无需进行检查。"

  $"
  # Notes

  ($existing)

  "
  | str dedent
  | save ($dir | path join notes.md)

  let payload = {
    tool_name: Edit
    tool_input: {
      file_path: ($dir | path join notes.md)
      old_string: $existing
      new_string: (
        $"
        ($existing)

        ($PARAGRAPH)
        "
        | str dedent
      )
    }
  }

  let result = (polish $payload [$SIMPLIFY])

  assert equal ($result.calls | flatten | get text) [$PARAGRAPH]
  assert equal $result.input.new_string (
    $"
    ($existing)

    ($POLISHED)
    "
    | str dedent
  )
}

def "test an English passage is left alone" [] {
  let english = "Run the flake check before you push, since it utilizes the same hooks as CI."
  let document = (
    $"
    ($english)

    ($PARAGRAPH)
    "
    | str dedent
  )

  let result = (polish (write notes.md $document) [$SIMPLIFY])

  assert equal ($result.calls | flatten | get text) [$PARAGRAPH]
  assert equal $result.input.content (
    $"
    ($english)

    ($POLISHED)
    "
    | str dedent
  )
}

def "test only a truthy session switch leaves the call alone" [] {
  let cases = [
    [value calls content];
    ["1" [] null]
    [TRUE [] null]
    ["0" [$PARAGRAPH] $POLISHED]
  ]

  for case in $cases {
    let session = {DISABLE_PROSE_POLISH: $case.value}

    let result = (polish (write notes.md $PARAGRAPH) [$SIMPLIFY] $session)

    let context = ($session | to nuon)
    assert equal ($result.calls | flatten | get text) $case.calls $context
    assert equal ($result.input | get --optional content) $case.content $context
  }
}

def "test indented lines inside a fence still let the document through" [] {
  let document = (
    $"
    ($PARAGRAPH)

    ```nix
    {
        enable = true;
    }
    ```
    "
    | str dedent
  )

  let result = (polish (write notes.md $document) [$SIMPLIFY])

  assert equal ($result.calls | flatten | get text) [$PARAGRAPH]
  assert equal $result.input.content ($document | str replace $PARAGRAPH $POLISHED)
}

def "test an indented code block outside a fence skips the document" [] {
  let document = (
    $"
    ($PARAGRAPH)

        nix flake check
    "
    | str dedent
  )

  let result = (polish (write notes.md $document) [$SIMPLIFY])

  assert equal $result.calls []
  assert equal $result.input null
}

def "test a rewrite that drops a code span is repaired with the reason" [] {
  let result = (polish (write notes.md $PARAGRAPH) [$DROP_CODE $SIMPLIFY])

  assert equal ($result.calls | get 1) [
    {
      id: 0
      text: $PARAGRAPH
      rejected: ($PARAGRAPH | str replace $DROP_CODE.find $DROP_CODE.replace)
      problem: "a code span, link, URL, number, or quoted span was dropped or edited"
    }
  ]
  assert equal $result.input.content $POLISHED
}

def "test a rewrite that stays faulty keeps the agent text" [] {
  let result = (polish (write notes.md $PARAGRAPH) [$DROP_CODE $ADD_SEMICOLON])

  assert equal ($result.calls | flatten | get text) [$PARAGRAPH $PARAGRAPH]
  assert equal $result.input null
}
