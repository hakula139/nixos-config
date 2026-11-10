#!/usr/bin/env nu

# ==================================================================================================
# Prose Polish Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "prose-polish.nu")
const FIXTURES = ($SCRIPT_DIR | path join "fixtures")

const PROMPT = "Shared rules."
const REPAIR_PROMPT = "Repair rules."

# Runs the script with stub rules and config, as the wrapper does. `run` is the completed script
# and `calls` each model call's `model`, `user` message, and `passages`.
def command [args: list<string>, stdin: any, rules: list<record>]: nothing -> record {
  let dir = (mktemp --directory)
  let rules_file = ($dir | path join "rules.json")
  let config_file = ($dir | path join "config.json")
  let log = ($dir | path join "calls.jsonl")

  $rules
  | to json
  | save $rules_file

  {
    modelCall: ($env.NU_TEST_STUBS | path join "model-call")
    phrasing: ""
    maxRepairs: 1
    model: "stub"
    prompt: $PROMPT
    repairPrompt: $REPAIR_PROMPT
    models: {gemini-3.8-flash: "gateway/gemini-3.8-flash"}
  }
  | to json
  | save $config_file

  let run = with-env {
    STUB_LOG: $log
    STUB_RULES: $rules_file
    PROSE_POLISH_CONFIG: $config_file
  } {
    (
      $stdin
      | ^$nu.current-exe --no-config-file
        $SCRIPT
          ...$args
      | complete
    )
  }
  let calls = if ($log | path exists) {
    open $log | from json --objects
  } else {
    []
  }
  {run: $run, calls: $calls}
}

# A category's case directories, each with the `case.nuon` it holds when it has one, defaulted for
# the fields a case leaves out.
def cases [category: string]: nothing -> list<record> {
  ls ($FIXTURES | path join $category)
  | where type == "dir"
  | sort-by name
  | each {|entry|
    let dir = ($entry.name | path expand)
    let file = ($dir | path join "case.nuon")
    let given = if ($file | path exists) {
      open --raw $file | from nuon
    } else {
      {}
    }
    let data = ({rules: [], args: [], forwarded: ""} | merge $given)
    {name: ($dir | path basename), dir: $dir, data: $data}
  }
}

# One case by name from `category`.
def case [category: string, name: string]: nothing -> record {
  cases $category | where name == $name | get 0
}

def bytes [path: string]: nothing -> binary {
  open --raw $path | into binary
}

# Runs `case` in place on a copy, where it must print nothing, and through stdin. `output` is the
# written file or the printed document, and `untouched` holds when the copy kept its mtime.
def modes [case: record, rules: list<record>, args: list<string>]: nothing -> list<record> {
  let input = ($case.dir | path join "input.md")
  let path = (mktemp --directory | path join "input.md")
  cp $input $path
  chmod u+w $path
  let modified = (ls $path | get 0.modified)

  let file = (command [...$args $path] "" $rules)
  assert equal $file.run.stdout "" $"($case.name) file"
  let untouched = ((ls $path | get 0.modified) == $modified)
  let piped = (command $args (bytes $input) $rules)
  [
    {name: "file", ...$file, output: (bytes $path), untouched: $untouched}
    {name: "stdin", ...$piped, output: ($piped.run.stdout | encode utf-8), untouched: true}
  ]
}

# A document of `count` one-line paragraphs whose passage text exceeds one batch.
def long-document [count: int]: nothing -> string {
  let sentence = "The river carries the boat past the quiet mills while the fox sleeps."
  let filler = (1..5 | each { $sentence } | str join " ")
  1..$count | each {|n| $"Paragraph ($n). ($filler)" } | str join "\n\n"
}

def "test the default model and --model" [] {
  let target = (case polish ideographic-indent)
  let input = (bytes ($target.dir | path join "input.md"))

  let default = (command [] $input $target.data.rules)
  assert equal $default.run.exit_code 0 $default.run.stderr
  assert equal ($default.calls | get model) ["stub"]

  let chosen = (command [--model gemini-3.8-flash] $input $target.data.rules)
  assert equal $chosen.run.exit_code 0 $chosen.run.stderr
  assert equal ($chosen.calls | get model) ["gateway/gemini-3.8-flash"]
}

def "test a caller-supplied config is rejected" [] {
  let result = (command [--config config.json] "" [])

  assert equal $result.run.exit_code 1
  assert ($result.run.stderr | str contains "unknown flag") $result.run.stderr
}

def "test polish cases" [] {
  for case in (cases polish) {
    let expected = (bytes ($case.dir | path join "expected.md"))

    for mode in (modes $case $case.data.rules []) {
      let context = $"($case.name) ($mode.name)"
      assert equal $mode.run.exit_code 0 $"($context): ($mode.run.stderr)"
      assert equal $mode.run.stderr "" $context
      assert equal $mode.output $expected $context
      assert equal $mode.calls.0.passages.text $case.data.sent $context
    }
  }
}

def "test skip cases" [] {
  for case in (cases skip) {
    let input = (bytes ($case.dir | path join "input.md"))

    for mode in (modes $case [] []) {
      let context = $"($case.name) ($mode.name)"
      assert equal $mode.run.exit_code 0 $"($context): ($mode.run.stderr)"
      assert equal $mode.run.stderr "" $context
      assert equal $mode.output $input $context
      assert equal $mode.calls [] $context
      assert $mode.untouched $context
    }
  }
}

def "test refuse cases" [] {
  let kept = "prose-polish: kept this passage because its rewrite failed a check:"

  for case in (cases refuse) {
    let input = (bytes ($case.dir | path join "input.md"))
    let report = $"($kept) ($case.data.problem)\n($input | decode utf-8 | str trim)\n"

    for mode in (modes $case $case.data.rules []) {
      let context = $"($case.name) ($mode.name)"
      assert equal $mode.run.exit_code 0 $"($context): ($mode.run.stderr)"
      assert equal $mode.run.stderr $report $context
      assert equal $mode.output $input $context
      assert $mode.untouched $context
    }
  }
}

def "test a refused rewrite is retried with its reason" [] {
  let target = (case polish repair-succeeds)
  let document = (bytes ($target.dir | path join "input.md"))
  let opening = $target.data.rules.0
  let repair = $target.data.rules.1
  let paragraph = $target.data.sent.1
  let polished = (open --raw ($target.dir | path join "expected.md"))
  let kept = (
    $polished
    | str replace ($paragraph | str replace $repair.find $repair.replace) $paragraph
  )
  let rejected = ($paragraph | str replace $opening.find $opening.replace)
  let problem = 'the rewrite dropped the code span "`utilizes`" and added "`uses`"'

  let variants = [
    [name repair];
    ["add a semicolon" {find: "，", replace: "; "}]
    ["malformed reply" {reply: "{"}]
  ]

  for variant in $variants {
    let result = (command [] $document [$opening $variant.repair])
    let context = $variant.name

    assert equal $result.run.exit_code 0 $"($context): ($result.run.stderr)"
    assert equal $result.run.stdout $kept $context
    assert equal ($result.calls | length) 2 $context
    assert equal ($result.calls | get 1.passages) [
      {
        id: 1
        text: $paragraph
        rejected: $rejected
        problem: $problem
      }
    ] $context
    assert str contains ($result.calls | get 0.user) $PROMPT $context
    assert str contains ($result.calls | get 1.user) $REPAIR_PROMPT $context
  }
}

def "test a long document is batched with the whole document as context" [] {
  let document = (long-document 60)
  let rule = {find: "river", replace: "stream"}

  let result = (command [] ($document | encode utf-8) [$rule])
  let calls = $result.calls

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal ($calls | length) 2 "the passages split into two batches"
  assert equal ($calls | get 0.passages | get id) (seq 0 54) "the first batch stops at the budget"
  assert equal ($calls | get 1.passages | get id) (seq 55 59) "the second batch takes the rest"
  for call in $calls {
    assert str contains $call.user $document "each call carries the whole document"
  }
  assert equal $result.run.stdout ($document | str replace --all "river" "stream")
}

def "test a failed later batch leaves the file untouched" [] {
  let document = (long-document 60)
  let rule = {find: "river", replace: "stream"}
  let path = (mktemp --directory | path join "input.md")
  $document | save --raw $path

  let result = (command [$path] "" [$rule {fail: "boom"}])

  assert equal $result.run.exit_code 1 "a failed later batch ends the run"
  assert equal (bytes $path) ($document | encode utf-8) "the file stays untouched"
}

def "test a long document repairs each batch with the whole document as context" [] {
  let document = (long-document 60)
  let paragraphs = ($document | split row "\n\n")
  let opening = {find: "river", replace: "river;"}
  let repair = {find: "river", replace: "stream"}
  let repaired = ($document | str replace --all "river" "stream")
  let head = ($paragraphs | first 55 | str join "\n\n")
  let tail = ($paragraphs | skip 55 | str join "\n\n")
  let partial = $"($head | str replace --all "river" "stream")\n\n($tail)"

  let variants = [
    [name rules expected kept];
    ["every repair batch succeeds" [$opening $opening $repair $repair] $repaired 0]
    ["a later repair batch fails" [$opening $opening $repair {fail: "boom"}] $partial 5]
  ]

  for variant in $variants {
    let result = (command [] ($document | encode utf-8) $variant.rules)
    let calls = $result.calls

    assert equal $result.run.exit_code 0 $"($variant.name): ($result.run.stderr)"
    assert equal ($calls | length) 4 $"($variant.name): two opening and two repair calls"
    for call in ($calls | skip 2) {
      assert str contains $call.user $document $"($variant.name): document context"
    }
    assert equal $result.run.stdout $variant.expected $variant.name
    let kept = (
      $result.run.stderr
      | lines
      | where {|line| $line | str starts-with "prose-polish: kept this passage" }
      | length
    )
    assert equal $kept $variant.kept $"($variant.name): kept passages"
  }
}

def "test fail cases" [] {
  for case in (cases fail) {
    let report = $"($case.data.forwarded)prose-polish: ($case.data.stderr)\n"

    for mode in (modes $case $case.data.rules $case.data.args) {
      let context = $"($case.name) ($mode.name)"
      assert equal $mode.run.exit_code 1 $context
      assert equal $mode.run.stdout "" $context
      assert equal $mode.run.stderr $report $context
      assert equal ($mode.calls | length) ($case.data.rules | length) $context
      assert $mode.untouched $context
    }
  }
}
