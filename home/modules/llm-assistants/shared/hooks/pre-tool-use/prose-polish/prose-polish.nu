#!/usr/bin/env nu

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

def protected [text: string]: nothing -> list {
  [
    # Fenced code blocks
    ($text | parse --regex $FENCE)
    # Inline code
    ($text | parse --regex '(?<m>`[^`\n]+`)')
    # ATX headings
    ($text | parse --regex '(?m)^(?<m>#{1,6} .*)$')
    # Setext headings
    ($text | parse --regex '(?m)^(?<m>.+\n[=-]{2,}\s*)$')
    # Inline link destinations
    ($text | parse --regex '\]\((?<m>[^)]+)\)')
    # Reference link destinations
    ($text | parse --regex '(?m)^\s*\[[^]]+\]:\s*(?<m>\S+)')
    # List markers
    ($text | parse --regex '(?m)^(?<m>\s*(?:[-*+]|\d+\.) )')
    # YAML front matter
    ($text | parse --regex '(?s)\A(?<m>---\n.*?\n---(?:\n|\z))')
    # Table rows
    ($text | parse --regex '(?m)^(?<m>\s*\|.*\|\s*)$')
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
}

def margins [text: string]: nothing -> list<string> {
  [
    # Leading whitespace
    ($text | parse --regex '(?s)\A(?<m>\s*)' | get -o 0.m | default "")
    # Trailing whitespace
    ($text | parse --regex '(?s)(?<m>\s*)\z' | get -o 0.m | default "")
  ]
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

def targets [payload: record, mcp_fields: record]: nothing -> list<record> {
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

  mut fields = ($mcp_fields | get -o $tool | default [])
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

def polish [items: list<string>, config: record]: nothing -> list<string> {
  # Claude profile API suffix
  let base = ($env | get -o ANTHROPIC_BASE_URL | default "" | str replace -r '/anthropic$' '')
  let token = ($env | get -o ANTHROPIC_AUTH_TOKEN | default "")
  if ($base | is-empty) or ($token | is-empty) {
    return []
  }

  let instruction = ($config.prompt | str trim)
  let passages = (
    $items
    | enumerate
    | each {|item| {id: $item.index, text: $item.item} }
  )
  let body = {
    model: $config.model
    max_tokens: 16384
    stream: false
    response_format: {type: "json_object"}
    messages: [
      {role: "system", content: $config.phrasing}
      {
        role: "user"
        content: ([
          $instruction
          ""
          "The input is a JSON object. Return only the same object shape and numeric IDs, replacing each text value with its rewrite."
          ""
          ({passages: $passages} | to json --raw)
        ] | str join "\n")
      }
    ]
  }

  let ca = ($env | get -o NODE_EXTRA_CA_CERTS | default "")
  let cacert = if ($ca | is-empty) { [] } else { [--cacert $ca] }
  let curl = $config.curl
  # The gateway's advertised IPv6 endpoint closes during TLS.
  let run = (
    $body
    | to json
    | ^$curl --ipv4 --silent --show-error --fail --max-time $config.polishTimeout
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

  let response = ($run.stdout | from json)
  if ($response | get -o choices.0.finish_reason | default "") != "stop" {
    return []
  }
  let reply = ($response | get -o choices.0.message.content | default "")
  let parsed = ($reply | from json)
  let rewritten = ($parsed | get -o passages | default [])
  let expected = (0..<($items | length) | each {|i| $i })
  if ($rewritten | length) != ($items | length) or ($rewritten | get -o id) != $expected {
    return []
  }
  let out = ($rewritten | get -o text)
  if ($out | any {|text| ($text | describe) != "string" or ($text | is-empty) }) {
    []
  } else {
    $out
  }
}

def acceptable [before: string, after: string]: nothing -> bool {
  ((margins $after) == (margins $before)
    and (protected $after) == (protected $before))
}

def polished [config: record]: nothing -> any {
  let payload = (^cat | from json)
  let found = (targets $payload $config.mcpProseFields)
  if ($found | is-empty) {
    return null
  }

  let rewritten = (polish ($found | get text) $config)
  mut args = ($payload | get tool_input)
  mut changed = false
  for pair in ($found | zip $rewritten) {
    if $pair.0.text != $pair.1 and (acceptable $pair.0.text $pair.1) {
      $args = ($args | update ($pair.0.path | into cell-path) $pair.1)
      $changed = true
    }
  }
  if $changed == false {
    return null
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
