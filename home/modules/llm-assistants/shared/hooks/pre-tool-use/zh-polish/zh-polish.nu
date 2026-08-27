#!/usr/bin/env nu

# ==============================================================================
# Chinese Polish (PreToolUse)
# ==============================================================================
# Hands the Chinese in a tool's input to a better Chinese writer and substitutes
# the rewrite back before the tool runs. The event is what buys the coverage: by
# PostToolUse a page, a commit body or a question has already gone out.
# ==============================================================================

const PROMPT_FILE = "@promptFile@"
const DOCTRINE_FILE = "@doctrineFile@"
const MODEL = "@model@"
const POLISH_TIMEOUT = "@polishTimeout@"
const CURL = "@curl@"

const CJK = '(?<c>[\x{4e00}-\x{9fff}])'
const FENCE = '(?s)```.*?```'

# A whole-file Write is only worth a call once the file is largely Chinese. An
# Edit carries just the span that changed, so one sentence is enough there.
const MIN_CJK_FILE = 120
const MIN_CJK_SPAN = 8
const MIN_RATIO = 0.55
const MAX_RATIO = 1.6

# `header` caps at 12 characters and `label` at a few words, so a rewrite the
# ratio check accepts can still overflow the tool's own schema.
const CAPPED = [header label]
const MCP_FIELDS = [content body message description note new_content]

def prose-cjk [text: string]: nothing -> int {
  $text | str replace --regex --all $FENCE "" | parse --regex $CJK | length
}

def structure [text: string]: nothing -> list {
  [
    ($text | parse --regex '(?s)(?<m>```.*?```)')
    ($text | parse --regex '(?<m>`[^`\n]+`)')
    ($text | parse --regex '(?m)^(?<m>#{1,6} .*)$')
    ($text | parse --regex '\]\((?<m>[^)]+)\)')
    ($text | parse --regex '(?m)^(?<m>\s*(?:[-*+]|\d+\.) )')
  ]
}

def collect [node: any, floor: int, path: list]: nothing -> list<record> {
  let kind = ($node | describe --detailed | get type)
  match $kind {
    "string" => (if (prose-cjk $node) >= $floor { [{path: $path, text: $node}] } else { [] })
    "record" => (
      $node
      | columns
      | where {|key| $key not-in $CAPPED }
      | each {|key| collect ($node | get $key) $floor ($path | append $key) }
      | flatten
    )
    "list" => (
      $node | enumerate | each {|e| collect $e.item $floor ($path | append $e.index) } | flatten
    )
    _ => [],
  }
}

def targets [payload: record]: nothing -> list<record> {
  let tool = ($payload | get -o tool_name | default "")
  let args = ($payload | get -o tool_input)
  if ($args | describe | str starts-with "record") == false {
    return []
  }

  # Only Markdown is eligible: rewriting a source file to polish one Chinese
  # comment risks the code around it.
  let file = match $tool {
    "Write" => {key: "content", floor: $MIN_CJK_FILE}
    "Edit" => {key: "new_string", floor: $MIN_CJK_SPAN}
    _ => null,
  }
  if $file != null {
    let target = ($args | get -o file_path)
    if ($target | describe) != "string" or ($target | str ends-with ".md") == false {
      return []
    }
    let text = ($args | get -o $file.key)
    if ($text | describe) == "string" and (prose-cjk $text) >= $file.floor {
      return [{path: [$file.key], text: $text}]
    }
    return []
  }

  if $tool == "AskUserQuestion" {
    return (collect ($args | get -o questions) $MIN_CJK_SPAN [questions])
  }

  if ($tool | str starts-with "mcp__") {
    return (
      $MCP_FIELDS
      | each {|key|
        let text = ($args | get -o $key)
        if ($text | describe) == "string" and (prose-cjk $text) >= $MIN_CJK_SPAN {
          {path: [$key], text: $text}
        }
      }
      | compact
    )
  }
  []
}

def polish [items: list<string>]: nothing -> list<string> {
  let base = ($env | get -o ANTHROPIC_BASE_URL | default "" | str replace -r '/anthropic$' '')
  let token = ($env | get -o ANTHROPIC_AUTH_TOKEN | default "")
  if ($base | is-empty) or ($token | is-empty) {
    return []
  }

  # Everything above the horizontal rule is a note to whoever edits that file.
  let instruction = (open --raw $PROMPT_FILE | into string | split row "\n---\n" | last | str trim)
  let numbered = ($items | enumerate | each {|e| $"<<<($e.index)>>>\n($e.item)" } | str join "\n\n")
  let body = {
    model: $MODEL
    max_tokens: 16384
    stream: false
    messages: [
      {role: "system", content: (open --raw $DOCTRINE_FILE | into string)}
      {
        role: "user"
        content: ([
          $instruction
          ""
          $"There are ($items | length) passages below, each introduced by a <<<n>>> line."
          "Rewrite them one by one, keeping the same numbering and order, and keep the"
          "<<<n>>> line in front of each. Do not merge, split, add, or drop a passage."
          ""
          $numbered
        ] | str join "\n")
      }
    ]
  }

  # The gateway CA lives in a file the runtime exports, not the trust store.
  let ca = ($env | get -o NODE_EXTRA_CA_CERTS | default "")
  let cacert = if ($ca | is-empty) { [] } else { [--cacert $ca] }
  let run = (
    $body
    | to json
    | ^$CURL --silent --show-error --fail --max-time $POLISH_TIMEOUT
      ...$cacert
      --header $"Authorization: Bearer ($token)"
      --header "content-type: application/json"
      --data @-
      $"($base)/v1/chat/completions"
    | complete
  )
  if $run.exit_code != 0 {
    return []
  }

  let reply = ($run.stdout | from json | get -o choices.0.message.content | default "")
  let parts = ($reply | parse --regex '(?s)<<<(?<i>\d+)>>>\n(?<t>.*?)(?=\n*<<<\d+>>>|\z)')
  let out = (
    0..<($items | length)
    | each {|i| $parts | where i == ($i | into string) | get -o 0.t | default "" | str trim }
  )
  # A dropped or merged segment means the numbering was not honoured, and a
  # partial application would silently lose text.
  if ($out | any {|text| $text | is-empty }) { [] } else { $out }
}

def acceptable [before: string, after: string]: nothing -> bool {
  if ($after | is-empty) {
    return false
  }
  let ratio = ((prose-cjk $after) / ([(prose-cjk $before) 1] | math max))
  ($ratio >= $MIN_RATIO) and ($ratio <= $MAX_RATIO) and (structure $after) == (structure $before)
}

def polished []: nothing -> any {
  let payload = (^cat | from json)
  if ($payload | describe | str starts-with "record") == false {
    return null
  }
  let found = (targets $payload)
  if ($found | is-empty) {
    return null
  }

  let rewritten = (polish ($found | get text))
  if ($rewritten | length) != ($found | length) {
    return null
  }

  mut args = ($payload | get tool_input)
  mut changed = []
  for pair in ($found | zip $rewritten) {
    if (acceptable $pair.0.text $pair.1) {
      $args = ($args | update ($pair.0.path | into cell-path) $pair.1)
      $changed = ($changed | append $pair.0.path.0)
    }
  }
  if ($changed | is-empty) {
    return null
  }

  # Only the keys touched go back: updatedInput merges into the real input, so a
  # key omitted here keeps whatever the caller passed.
  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse"
      updatedInput: ($args | select ...($changed | uniq))
    }
  }
  | to json --raw
}

def main [] {
  let out = (try { polished } catch { null })
  if $out != null {
    print $out
  }
}
