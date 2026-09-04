#!/usr/bin/env nu

# ==============================================================================
# Prose Polish
# ==============================================================================

# Match complete triple-backtick blocks because Rust regexes cannot pair arbitrary
# delimiters. Either delimiter takes the three leading spaces CommonMark allows.
const FENCE = '(?ms)^(?<m> {0,3}```[^\n]*\n.*?^ {0,3}```\s*$)'
# Fence delimiters, for tracking which pieces sit inside one. Only whitespace may
# follow a closing delimiter, so a line carrying an info string never closes a fence.
const OPENER = '\A {0,3}```'
const CLOSER = '\A {0,3}```\s*\z'
# YAML or TOML front matter
const FRONT = '(?s)\A(?<m>(?:---|\+\+\+)\r?\n.*?\r?\n(?:---|\+\+\+)(?:\r?\n|\z))'
# Han characters
const HAN = '(?<c>[\x{4e00}-\x{9fff}])'
# Latin-script letters
const LATIN = '(?<c>\p{Latin})'

const MIN_HAN = 8
const MIN_LATIN = 32

# Compared by count, so a passage keeps whatever it arrived with and only the
# rewriter is held to the ban. Chinese prose takes the fullwidth `；`.
const BANNED_MARKS = ['—' '--' '…' ';']

def prose [text: string]: nothing -> string {
  $text | str replace --regex --all $FENCE ""
}

def count [text: string, pattern: string]: nothing -> int {
  prose $text | parse --regex $pattern | length
}

def enough-prose [text: string]: nothing -> bool {
  (count $text $HAN) >= $MIN_HAN or (count $text $LATIN) >= $MIN_LATIN
}

def supported-markdown [text: string]: nothing -> bool {
  # Front matter is data, and a post's indented list values read as an indented code block.
  let body = ($text | str replace --regex $FRONT "")
  let content = (prose $body)
  # Long backtick fences, tilde fences, and indented code blocks
  let supported_blocks = ($body | parse --regex '(?m)^(?<m>(?:`{4,}|~{3,}|(?: {4,}| {0,3}\t)[ \t]*\S))' | is-empty)
  let supported_inline = (not ($content | str contains "``"))
  # Raw HTML code containers
  let supported_html = ($body | parse --regex '(?i)(?<m><(?:pre|code|script|style)(?:\s|>))' | is-empty)
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
    # Front matter
    ($text | parse --regex $FRONT)
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

# Line endings are formatting, so comparisons run on one form and a rewrite takes
# back whichever form its own piece arrived in.
def unix [text: string]: nothing -> string {
  $text | str replace --all "\r\n" "\n"
}

def match-endings [sample: string, text: string]: nothing -> string {
  if ($sample | str contains "\r\n") {
    unix $text | str replace --all "\n" "\r\n"
  } else {
    $text
  }
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

# Blank-line-separated pieces, each carrying the separator that follows it, so a
# rewrite goes back by position and every piece left alone stays byte-identical.
def pieces [text: string]: nothing -> list<record> {
  # Front matter goes in whole and never counts as prose, whatever blank lines it holds.
  let front = ($text | parse --regex $FRONT | get -o 0.m | default "")
  mut out = if ($front | is-empty) { [] } else { [{block: $front, sep: "", prose: false}] }
  mut inside = false
  for piece in (($text | str substring ($front | str length)..) | parse --regex '(?s)(?<block>.*?)(?<sep>\n\s*\n|\z)') {
    # A fence holding a blank line splits across pieces, and no piece of one is prose.
    mut state = $inside
    for line in ($piece.block | lines) {
      $state = if $state {
        not ($line | parse --regex $CLOSER | is-not-empty)
      } else {
        ($line | parse --regex $OPENER | is-not-empty)
      }
    }
    let ends_inside = $state
    $out = ($out | append ($piece | insert prose ((not $inside) and (not $ends_inside))))
    $inside = $ends_inside
  }
  $out
}

def blocks [text: string]: nothing -> list<string> {
  pieces $text | where prose | each {|slot| unix $slot.block | str trim }
}

# A rewrite goes back by piece position, since the same text can occur elsewhere in
# the field. Separators come back untouched, so a piece nobody edited stays byte-identical.
def splice [text: string, edits: list<record>]: nothing -> string {
  pieces $text
  | enumerate
  | each {|slot|
    let edit = ($edits | where piece == $slot.index | get -o 0)
    # A rewrite arrives trimmed, so the piece's own margins carry its indent back.
    let block = if $edit == null {
      $slot.item.block
    } else {
      reframe $slot.item.block (match-endings $slot.item.block $edit.after)
    }
    $block + $slot.item.sep
  }
  | str join ""
}

def target [path: list, text: any, piece: any = null]: nothing -> list<record> {
  if ($text | describe) == "string" and (supported-markdown $text) and (enough-prose $text) {
    [{path: $path, before: (unix $text), piece: $piece}]
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

# Blocks the document already holds, or null when the file resists reading or parsing.
# Held blocks are one side of an equality test, so a short list would mark prose the
# write never touched as newly introduced. They are compared as a set, so a paragraph
# the document already holds stays untouched even when the write adds another copy.
def held-blocks [path: string]: nothing -> any {
  let disk = (try { open --raw $path } catch { null })
  if ($disk | describe) == "string" {
    return (if (supported-markdown $disk) { blocks $disk } else { null })
  }
  # A read fails both for a file that is absent and for one that cannot be reached,
  # and only absence means every block is new. Listing the parent tells them apart.
  let siblings = (
    try { ls --all ($path | path dirname) | get name | each {|name| $name | path basename } } catch { null }
  )
  if $siblings == null or (($path | path basename) in $siblings) {
    null
  } else {
    []
  }
}

def file-targets [args: record, key: string]: nothing -> list<record> {
  if (not ($args.file_path | str ends-with ".md")) {
    return []
  }
  let text = ($args | get -o $key)
  # Splitting a document this cannot parse would strand a fence interior.
  if ($text | describe) != "string" or (not (supported-markdown $text)) {
    return []
  }
  # Only the blocks a write introduces are the agent's own prose. An `Edit` carries
  # context lines the document already holds, and those are not the agent's to rewrite.
  let held = (held-blocks $args.file_path)
  if $held == null {
    return []
  }

  pieces $text
  | enumerate
  | where {|slot| $slot.item.prose and ((unix $slot.item.block | str trim) not-in $held) }
  | each {|slot| target [$key] ($slot.item.block | str trim) $slot.index }
  | flatten
}

def targets [payload: record, config: record]: nothing -> list<record> {
  let tool = ($payload | get tool_name)
  let args = ($payload | get tool_input)

  let key = match $tool {
    "Write" => "content"
    "Edit" => "new_string"
    _ => null,
  }
  if $key != null {
    return (file-targets $args $key)
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
  if (not ($parsed | describe | str starts-with "record")) {
    return []
  }
  # An id mismatch also catches a short, long, or id-less reply, and a rewrite
  # landing in another passage's slot would corrupt both.
  let rewritten = ($parsed | get -o passages | default [])
  if ($rewritten | get -o id) != ($passages | get id) {
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

def grade [target: record, raw: string]: nothing -> record {
  let after = (reframe $target.before $raw)
  $target | merge {after: $after, problem: (violations $target.before $after | str join "; ")}
}

def polished [config: record]: nothing -> any {
  let payload = (^cat | from json)
  let found = (targets $payload $config)
  if ($found | is-empty) {
    return null
  }

  let opening = (
    call-model ($found | enumerate | each {|slot| {id: $slot.index, text: $slot.item.before} }) [] $config
  )
  if ($opening | is-empty) {
    return null
  }

  mut graded = ($found | zip $opening | each {|pair| grade $pair.0 $pair.1 })

  # A fault drives the next round rather than vetoing the result outright, since the
  # rewriter usually repairs it once told what broke.
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
      $graded = ($graded | update $pair.0.index (grade $pair.0.item $pair.1))
    }
  }

  # A passage that still trips a check keeps the agent's own text. Better prose is not
  # worth a dropped code span, and the checks only fire on something already lost.
  let edits = ($graded | where problem == "" and after != before)
  if ($edits | is-empty) {
    return null
  }

  mut args = ($payload | get tool_input)
  for edit in ($edits | where piece == null) {
    $args = ($args | update ($edit.path | into cell-path) $edit.after)
  }

  let spliced = ($edits | where piece != null)
  if not ($spliced | is-empty) {
    let cell = ($spliced.0.path | into cell-path)
    $args = ($args | update $cell (splice ($args | get $cell) $spliced))
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
