#!/usr/bin/env nu

# ==============================================================================
# Prose Style Gate (PostToolUse)
# ==============================================================================
# Judges the prose the assistant wrote via a headless `claude -p` call, emitting
# additionalContext (non-halting) on a violation. Fails open on any error.
# ==============================================================================

const TIMEOUT = "@timeout@"
const PROMPT_FILE = "@promptFile@"
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
      if ($found | is-not-empty) { $found } else { $args | get -o $field | default "" }
    })
  }
  match $tool {
    "Write" => ($args | get -o content | default "")
    "Edit" => ($args | get -o new_string | default "")
    "apply_patch" => ($args | get -o command | default "")
    _ => ""
  }
}

# The verdict sits under `.result`, sometimes wrapped in a code fence, so take
# the outermost braces. `from json` returns non-JSON text unchanged rather than
# raising, hence the shape check.
def verdict-of [raw: string]: nothing -> record {
  let outer = ($raw | from json)
  if ($outer | describe | str starts-with "record") == false {
    return {}
  }
  let found = (
    $outer
    | get -o result
    | default ""
    | str replace --all "\n" ""
    | parse --regex '(?<json>\{.*\})'
    | get json
  )
  if ($found | is-empty) {
    return {}
  }
  let parsed = ($found | first | from json)
  if ($parsed | describe | str starts-with "record") == false { {} } else { $parsed }
}

def judge [content: string]: nothing -> string {
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
        "--" $content
      | complete
    )
  }
  if $run.exit_code == 0 { $run.stdout } else { "" }
}

def gate []: nothing -> any {
  if ($env | get -o CLAUDE_PROSE_GATE_ACTIVE | default "" | is-not-empty) {
    return null
  }
  # `open /dev/stdin` re-opens fd 0 by path and raises ENXIO once the caller
  # passes a socket, which is what Node's `spawn` hands a hook.
  let input = (^cat | from json)
  if ($input | describe | str starts-with "record") == false {
    return null
  }
  let content = (content-of $input)
  if ($content | str trim | is-empty) or ($content | str length) < $MIN_CHARS {
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
