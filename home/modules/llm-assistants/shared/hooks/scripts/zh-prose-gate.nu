#!/usr/bin/env nu

# ==============================================================================
# Chinese Prose Gate (PostToolUse)
# ==============================================================================
# Measures the Chinese prose the assistant just wrote against this assistant's
# own unpolished-output fingerprint, then hands the numbers to a headless
# `claude -p` judge. Emits additionalContext (non-halting). Fails open on any
# error, and stays inert when no classifier was fitted for this assistant.
# ==============================================================================

const TIMEOUT = "@timeout@"
const FINGERPRINT = "@fingerprint@"
const PROMPT_FILE = "@promptFile@"
const MODEL_ID = "@modelId@"
const JUDGE_TIMEOUT = "@judgeTimeout@"

# Held-out rates at this threshold: 89% recall against 15% false positives for
# claude-code, 92% against 9% for codex. The judge then rules on whatever gets
# through, so the cheap check only has to skip what is clearly clean.
const SCORE_FLOOR = -0.4

const MCP_FIELDS = [message, description, body, note, content]

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
    # Added lines only: context lines are text the assistant did not write.
    "apply_patch" => (
      $args
      | get -o command
      | default ""
      | lines
      | where ($it | str starts-with "+")
      | each {|line| $line | str substring 1.. }
      | str join "\n"
    )
    _ => ""
  }
}

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
    | parse -r '(?<json>\{.*\})'
    | get json
  )
  if ($found | is-empty) {
    return {}
  }
  let parsed = ($found | first | from json)
  if ($parsed | describe | str starts-with "record") == false { {} } else { $parsed }
}

def judge [report: string, content: string]: nothing -> string {
  let run = with-env {CLAUDE_ZH_PROSE_GATE_ACTIVE: "1"} {
    cd /tmp
    (
      ^$TIMEOUT $JUDGE_TIMEOUT claude -p $"指标：($report)\n\n文本：\n($content)"
        --bare
        --system-prompt-file $PROMPT_FILE
        --model sonnet
        --output-format json
      | complete
    )
  }
  if $run.exit_code == 0 { $run.stdout } else { "" }
}

def gate []: nothing -> any {
  if ($env | get -o CLAUDE_ZH_PROSE_GATE_ACTIVE | default "" | is-not-empty) {
    return null
  }
  if ($FINGERPRINT | is-empty) or ($PROMPT_FILE | path exists) == false {
    return null
  }
  let input = (^cat | from json)
  if ($input | describe | str starts-with "record") == false {
    return null
  }
  let content = (content-of $input)
  if ($content | is-empty) {
    return null
  }
  # The classifier reports its own short-text and low-Chinese rejections through
  # a non-zero exit, since both leave the ratios unstable rather than noisy.
  let measured = ($content | ^$FINGERPRINT $MODEL_ID | complete)
  if $measured.exit_code != 0 or ($measured.stdout | is-empty) {
    return null
  }
  let report = ($measured.stdout | str trim)
  let score = ($report | from json | get -o score | default 0)
  if $score <= $SCORE_FLOOR {
    return null
  }
  let verdict = (verdict-of (judge $report $content))
  if ($verdict | get -o ai | default false) != true {
    return null
  }
  let tics = ($verdict | get -o tics | default [] | str join ", ")
  let fix = ($verdict | get -o fix | default "")
  {
    hookSpecificOutput: {
      hookEventName: "PostToolUse"
      additionalContext: ([
        $"Chinese AI-flavor gate flagged this. Tics: ($tics). Fix: ($fix)"
        "Apply it in place and continue."
        "The prescriptions add characters, so a longer result is expected."
      ] | str join " ")
    }
  }
  | to json
}

def main [] {
  let out = (try { gate } catch { null })
  if $out != null { print $out }
}
