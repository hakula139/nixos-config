#!/usr/bin/env nu

# ==============================================================================
# Prose Style Gate (PostToolUse)
# ==============================================================================
# Judges the prose the assistant wrote via a headless `claude -p` call, emitting
# additionalContext (non-halting) on a violation. Fails open on any error.
# ==============================================================================

const TIMEOUT = "@timeout@"
const PROMPT_FILE = "@promptFile@"
const CANDIDATES = "@candidates@"
const JUDGE_TIMEOUT = "@judgeTimeout@"

const MIN_CHARS = 12
const MCP_FIELDS = [message, description, body, note, content, new_content]

def content-of [input: record]: nothing -> string {
  let tool = ($input | get -o tool_name | default "")
  let args = ($input | get -o tool_input | default {})
  if ($args | describe | str starts-with "record") == false {
    return ""
  }
  if ($tool | str starts-with "mcp__") {
    return ($MCP_FIELDS | reduce --fold "" {|field, found|
      if ($found | is-not-empty) {
        $found
      } else {
        let v = ($args | get -o $field | default "")
        if ($v | describe) == "string" { $v } else { "" }
      }
    })
  }
  match $tool {
    "Write" => ($args | get -o content | default "")
    "Edit" => ($args | get -o new_string | default "")
    "apply_patch" => ($args | get -o command | default "")
    _ => ""
  }
}

# The judge scans in prose before the verdict, and that scan quotes the text
# under judgement, braces and all. The last line parsing as a JSON object with
# `ok` is therefore the only safe anchor.
def verdict-of [raw: string]: nothing -> record {
  let outer = ($raw | from json)
  if ($outer | describe | str starts-with "record") == false {
    return {}
  }
  let candidates = (
    $outer
    | get -o result
    | default ""
    | lines
    | reverse
    | each {|line| $line | parse --regex '(?<json>\{.*\})' | get json }
    | flatten
  )
  for candidate in $candidates {
    let parsed = (try { $candidate | from json } catch { null })
    if ($parsed | describe | str starts-with "record") and ($parsed | get -o ok) != null {
      return $parsed
    }
  }
  {}
}

# The judge missed literal tics it was staring at, so a regex enumerates them
# first and the judge only rules on whether each meets its exemption. Scanning
# is best-effort: an empty list still leaves the judge reading the full text.
def candidates-in [content: string]: nothing -> string {
  let run = (try { $content | ^$CANDIDATES | complete } catch { null })
  if $run == null or $run.exit_code != 0 { "" } else { $run.stdout | str trim }
}

def judge [content: string]: nothing -> string {
  let found = (candidates-in $content)
  let message = if ($found | is-empty) {
    $content
  } else {
    [
      "A scanner located these tic candidates. Rule on each against its exemption,"
      "and keep reading for the tics no regex can find."
      ""
      $found
      ""
      "The text under judgement follows."
      ""
      $content
    ] | str join "\n"
  }
  # `--` is required: content starting with `-`, such as a Markdown bullet, is
  # otherwise parsed as an unknown option and the judge never sees it.
  let run = with-env {CLAUDE_PROSE_GATE_ACTIVE: "1"} {
    cd /tmp
    (
      ^$TIMEOUT $JUDGE_TIMEOUT claude -p
        --bare
        --system-prompt-file $PROMPT_FILE
        --model sonnet
        --output-format json
        "--" $message
      | complete
    )
  }
  if $run.exit_code == 0 { $run.stdout } else { "" }
}

def gate []: nothing -> any {
  if ($env | get -o CLAUDE_PROSE_GATE_ACTIVE | default "" | is-not-empty) {
    return null
  }
  let input = (^cat | from json)
  if ($input | describe | str starts-with "record") == false {
    return null
  }
  let content = (content-of $input)
  # `str length` defaults to UTF-8 bytes.
  if ($content | str trim | is-empty) or ($content | str length --grapheme-clusters) < $MIN_CHARS {
    return null
  }
  if ($PROMPT_FILE | path exists) == false {
    return null
  }
  let verdict = (verdict-of (judge $content))
  if ($verdict | get -o ok | default true) != false {
    return null
  }
  let reason = ($verdict | get -o reason | default "prose style violation")
  {
    hookSpecificOutput: {
      hookEventName: "PostToolUse"
      additionalContext: $"Prose style gate flagged the text you just wrote. Fix it in place, then continue. ($reason)"
    }
  }
  | to json
}

def main [] {
  let out = (try { gate } catch { null })
  if $out != null { print $out }
}
