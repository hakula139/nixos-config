#!/usr/bin/env nu

# ==============================================================================
# Completeness Gate
# ==============================================================================

# Keep the original request and recent evidence within the judge's context budget.
def bounded [text: string]: nothing -> string {
  if ($text | str length) <= 160000 { return $text }
  [
    ($text | str substring 0..<20000)
    "[Middle of transcript omitted. Do not infer unfinished work from missing evidence.]"
    ($text | str substring (-140000)..)
  ] | str join "\n"
}

def gate [input: record, config: record]: nothing -> record {
  if ($input | get -o stop_hook_active | default false) { return {} }
  if $config.assistant == "cursor" {
    if ($input | get -o status | default "") != "completed" { return {} }
    if ($input | get -o loop_count | default 0) >= 1 { return {} }
  }

  let transcript = if ($input | get -o transcript | is-not-empty) {
    $input.transcript | to json
  } else {
    let path = ($input | get -o transcript_path | default "")
    if ($path | is-empty) { return {} }
    open --raw $path
  }
  if ($transcript | str trim | is-empty) { return {} }

  let caller = $config.modelCall
  let request = {
    system: $config.prompt
    user: ({
      transcript: (bounded $transcript)
      last_assistant_message: ($input | get -o last_assistant_message | default "")
    } | to json)
    maxTokens: 2048
    json: true
  }
  let run = ($request | to json | ^$caller | complete)
  if $run.exit_code != 0 { return {} }
  let verdict = ($run.stdout | from json)
  if ($verdict | describe | str starts-with "record") == false { return {} }
  if ($verdict | get -o ok | default true) != false { return {} }
  let reason = ($verdict | get -o reason | default "")
  if ($reason | describe) != "string" { return {} }
  if ($reason | str trim | is-empty) { return {} }

  if $config.assistant == "cursor" {
    {followup_message: $reason}
  } else {
    {decision: "block", reason: $reason}
  }
}

def main [config_file: string] {
  let out = (try { gate (^cat | from json) (open $config_file) } catch { {} })
  print ($out | to json --raw)
}
