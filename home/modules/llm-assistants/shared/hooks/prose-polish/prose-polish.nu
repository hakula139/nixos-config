#!/usr/bin/env nu

# ==============================================================================
# Prose Polish
# ==============================================================================

# Match complete triple-backtick blocks because Rust regexes cannot pair arbitrary delimiters.
const FENCE = '(?ms)^(?<m>```[^\n]*\n.*?^```\s*$)'
# Han characters
const HAN = '(?<c>[\x{4e00}-\x{9fff}])'
# Latin-script letters
const LATIN = '(?<c>\p{Latin})'

const MIN_HAN_FILE = 120
const MIN_HAN_SPAN = 8
const MIN_LATIN_FILE = 240
const MIN_LATIN_SPAN = 32

# Compared by count, so a passage keeps whatever it arrived with and only the
# rewriter is held to the ban. Chinese prose takes the fullwidth `；`.
const BANNED_MARKS = ['—' '--' '…' ';']

def prose [text: string]: nothing -> string {
  $text | str replace --regex --all $FENCE ""
}

def count [text: string, pattern: string]: nothing -> int {
  prose $text | parse --regex $pattern | length
}

def enough-prose [text: string, whole_file: bool]: nothing -> bool {
  let han_floor = if $whole_file { $MIN_HAN_FILE } else { $MIN_HAN_SPAN }
  let latin_floor = if $whole_file { $MIN_LATIN_FILE } else { $MIN_LATIN_SPAN }
  (count $text $HAN) >= $han_floor or (count $text $LATIN) >= $latin_floor
}

def supported-markdown [text: string]: nothing -> bool {
  let content = (prose $text)
  # Long backtick fences, tilde fences, and indented code blocks
  let supported_blocks = ($text | parse --regex '(?m)^(?<m>(?:`{4,}|~{3,}|(?: {4,}| {0,3}\t)[ \t]*\S))' | is-empty)
  # Multiple-backtick inline code
  let supported_inline = ($content | str contains "``") == false
  # Raw HTML code containers
  let supported_html = ($text | parse --regex '(?i)(?<m><(?:pre|code|script|style)(?:\s|>))' | is-empty)
  $supported_blocks and $supported_inline and $supported_html
}

# Block structure has to keep its order, since that is what the order encodes.
def structure [text: string]: nothing -> list {
  [
    # Fenced code blocks
    ($text | parse --regex $FENCE)
    # ATX headings
    ($text | parse --regex '(?m)^(?<m>#{1,6} .*)$')
    # Setext headings
    ($text | parse --regex '(?m)^(?<m>.+\n[=-]{2,}\s*)$')
    # List markers
    ($text | parse --regex '(?m)^(?<m>\s*(?:[-*+]|\d+\.) )')
    # YAML front matter
    ($text | parse --regex '(?s)\A(?<m>---\n.*?\n---(?:\n|\z))')
    # Table rows
    ($text | parse --regex '(?m)^(?<m>\s*\|.*\|\s*)$')
  ]
}

# Literal spans are compared as a multiset, because merging or reordering two
# sentences that each carry a quotation must stay allowed while losing or
# editing one must not.
def literals [text: string]: nothing -> list {
  [
    # Inline code
    ($text | parse --regex '(?<m>`[^`\n]+`)')
    # Inline link destinations
    ($text | parse --regex '\]\((?<m>[^)]+)\)')
    # Reference link destinations
    ($text | parse --regex '(?m)^\s*\[[^]]+\]:\s*(?<m>\S+)')
    # HTML tags
    ($text | parse --regex '(?<m></?[A-Za-z][^>\n]*>)')
    # URLs
    ($text | parse --regex '(?<m>https?://[^\s)>]+)')
    # Identifiers containing digits
    ($text | parse --regex '(?<m>(?<![A-Za-z0-9_])(?=[A-Za-z0-9_.:/+-]*[A-Za-z])(?=[A-Za-z0-9_.:/+-]*\d)[A-Za-z0-9_](?:[A-Za-z0-9_.:/+-]*[A-Za-z0-9_])?(?![A-Za-z0-9_]))')
    # Numbers with decimal segments and optional unit suffixes
    ($text | parse --regex '(?<m>[-+]?\d+(?:\.\d+)*(?:%|[A-Za-z]+)?)')
    # Quoted text
    ($text | parse --regex '(?<m>“[^”\n]*”|「[^」\n]*」|『[^』\n]*』|"[^"\n]*")')
  ]
  | each {|spans| $spans | get -o m | sort }
}

def margins [text: string]: nothing -> list<string> {
  [
    ($text | parse --regex '(?s)\A(?<m>\s*)' | get 0.m)
    ($text | parse --regex '(?s)(?<m>\s*)\z' | get 0.m)
  ]
}

def reframe [before: string, after: string]: nothing -> string {
  let edges = (margins $before)
  ($edges | get 0) + ($after | str trim) + ($edges | get 1)
}

def target [path: list, text: any, whole_file: bool = false]: nothing -> list<record> {
  if ($text | describe) == "string" and (supported-markdown $text) and (enough-prose $text $whole_file) {
    [{path: $path, text: $text}]
  } else {
    []
  }
}

def question-targets [questions: list<record>]: nothing -> list<record> {
  $questions
  | enumerate
  | each {|question|
    let prefix = [questions $question.index]
    let prompt = (target ($prefix | append question) $question.item.question)
    let options = (
      $question.item.options
      | enumerate
      | each {|option|
        target ($prefix | append options | append $option.index | append description) $option.item.description
      }
      | flatten
    )
    $prompt ++ $options
  }
  | flatten
}

def targets [payload: record, config: record]: nothing -> list<record> {
  let tool = ($payload | get tool_name)
  let args = ($payload | get tool_input)

  let file = match $tool {
    "Write" => {key: "content", whole_file: true}
    "Edit" => {key: "new_string", whole_file: false}
    _ => null,
  }
  if $file != null {
    if ($args.file_path | str ends-with ".md") == false {
      return []
    }
    return (target [$file.key] ($args | get -o $file.key) $file.whole_file)
  }

  if $tool == "AskUserQuestion" {
    return (question-targets ($args | get questions))
  }

  mut fields = ($config.mcpProseFields | get -o $tool | default [])
  if $tool in [mcp__Atlassian__confluence_create_page mcp__Atlassian__confluence_update_page] {
    let format = ($args | get -o content_format | default "markdown")
    if $format != "markdown" {
      $fields = ($fields | where $it != content)
    }
  }
  $fields
  | each {|key| target [$key] ($args | get -o $key) }
  | flatten
}

def call-model [passages: list<record>, notes: list<string>, config: record]: nothing -> list<string> {
  let request = {
    json: true
    maxTokens: 16384
    model: $config.model
    system: $config.phrasing
    user: (
      [
        ($config.prompt | str trim)
        ""
        "The input is a JSON object. Return only the same object shape and numeric IDs, replacing each text value with its rewrite."
      ]
      | append $notes
      | append ""
      | append ({passages: $passages} | to json --raw)
      | str join "\n"
    )
  }

  let caller = $config.modelCall
  let run = ($request | to json | ^$caller | complete)
  if $run.exit_code != 0 or ($run.stdout | str trim | is-empty) {
    return []
  }

  let parsed = ($run.stdout | from json)
  if ($parsed | describe | str starts-with "record") == false {
    return []
  }
  let rewritten = ($parsed | get -o passages | default [])
  if ($rewritten | length) != ($passages | length) or ($rewritten | get -o id) != ($passages | get id) {
    return []
  }
  let out = ($rewritten | get -o text)
  if ($out | any {|text| ($text | describe) != "string" or ($text | is-empty) }) {
    []
  } else {
    $out
  }
}

# The rewriter cannot see why a passage was refused, so hand the refused attempt
# back beside the reason.
def repair [pending: list<record>, config: record]: nothing -> list<string> {
  let passages = (
    $pending
    | each {|row|
      {id: $row.index, text: $row.item.before, rejected: $row.item.after, problem: $row.item.problem}
    }
  )
  call-model $passages ["" ($config.repairPrompt | str trim)] $config
}

def bare [text: string]: nothing -> string {
  prose $text
  # Inline code
  | str replace --regex --all '`[^`\n]+`' ""
  # URLs
  | str replace --regex --all 'https?://[^\s)>]+' ""
}

def adds-mark [before: string, after: string]: nothing -> bool {
  let source = (bare $before)
  let result = (bare $after)
  $BANNED_MARKS | any {|mark|
    ($result | split row $mark | length) > ($source | split row $mark | length)
  }
}

def violations [before: string, after: string]: nothing -> list<string> {
  mut found = []
  if (structure $after) != (structure $before) {
    $found = ($found | append "a heading, list marker, table row, or fenced block was altered, dropped, or moved")
  }
  if (literals $after) != (literals $before) {
    $found = ($found | append "a code span, link, URL, number, or quoted span was dropped or edited")
  }
  # A rewrite may merge lines, since rejoining clipped sentences is the point,
  # but gaining one means a paragraph was cut into pieces.
  if ($after | lines | length) > ($before | lines | length) {
    $found = ($found | append "the rewrite holds more lines than the input, so a paragraph was split")
  }
  if (adds-mark $before $after) {
    $found = ($found | append $"the rewrite introduced one of these marks: ($BANNED_MARKS | str join ' ')")
  }
  $found
}

def grade [path: list, before: string, raw: string]: nothing -> record {
  let after = (reframe $before $raw)
  {
    path: $path
    before: $before
    after: $after
    problem: (violations $before $after | str join "; ")
  }
}

def polished [config: record]: nothing -> any {
  let payload = (^cat | from json)
  let found = (targets $payload $config)
  if ($found | is-empty) {
    return null
  }

  let opening = (
    call-model ($found | get text | enumerate | each {|item| {id: $item.index, text: $item.item} }) [] $config
  )
  if ($opening | is-empty) {
    return null
  }

  mut graded = ($found | zip $opening | each {|pair| grade $pair.0.path $pair.0.text $pair.1 })

  # A fault drives the next round rather than vetoing the result. A rewrite that
  # still trips one reads better than the text the agent wrote, so the newest
  # attempt ships and only a dead model call leaves the original standing.
  for _ in 0..<$config.maxRepairs {
    let pending = ($graded | enumerate | where item.problem != "")
    if ($pending | is-empty) {
      break
    }
    let retried = (repair $pending $config)
    if ($retried | is-empty) {
      break
    }
    for pair in ($pending | zip $retried) {
      $graded = ($graded | update $pair.0.index (grade $pair.0.item.path $pair.0.item.before $pair.1))
    }
  }

  let edits = ($graded | where after != before)
  if ($edits | is-empty) {
    return null
  }

  mut args = ($payload | get tool_input)
  for edit in $edits {
    $args = ($args | update ($edit.path | into cell-path) $edit.after)
  }

  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse"
      updatedInput: $args
    }
  }
  | to json --raw
}

def main [config_file: string] {
  let out = (try { polished (open $config_file) } catch { null })
  if $out != null {
    print $out
  }
}
