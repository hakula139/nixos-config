#!/usr/bin/env nu

# ==============================================================================
# WakaTime Heartbeat for AI-Generated Code (PostToolUse)
# ==============================================================================
# Asks wakatime-cli to parse the assistant's transcript and send file-level AI
# heartbeats, mirroring the claude-code-wakatime plugin without letting the hook
# download or install its own CLI binary.
# ==============================================================================

const PLUGIN_NAME = "@pluginName@"
const TIMEOUT = "@timeout@"
const TOOL_TIMEOUT = "@toolTimeout@"

const ID_FIELDS = [transcript_path, session_id, "thread-id", thread_id, cwd]
const MAX_ID_CHARS = 160
const MAX_PLUGIN_CHARS = 80
const BEAT_INTERVAL = 60

# `from json` hands back non-JSON text unchanged rather than raising, and a
# payload the hook cannot read still earns a heartbeat, hence the empty record.
def payload []: nothing -> record {
  # `^cat`, since `open /dev/stdin` raises ENXIO on the socket Node's `spawn`
  # hands a hook.
  let parsed = (try { ^cat | from json } catch { {} })
  if ($parsed | describe | str starts-with "record") { $parsed } else { {} }
}

def text-field [input: record, field: string]: nothing -> string {
  let value = ($input | get -o $field | default "")
  if ($value | describe) == "string" { $value } else { "" }
}

def sanitize [raw: string, limit: int]: nothing -> string {
  $raw | str replace --all --regex '[^A-Za-z0-9._-]' '_' | str substring ..<$limit
}

def state-id [input: record]: nothing -> string {
  let found = ($ID_FIELDS | reduce --fold "" {|field, acc|
    if ($acc | is-not-empty) { $acc } else { text-field $input $field }
  })
  if ($found | is-empty) { "unknown" } else { $found }
}

def throttled [file: string, now: int]: nothing -> bool {
  let last = (try { open $file | str trim } catch { "" })
  if ($last =~ '^[0-9]+$') == false {
    return false
  }
  ($now - ($last | into int)) < $BEAT_INTERVAL
}

def wakatime-home []: nothing -> string {
  let override = ($env | get -o WAKATIME_HOME | default "")
  if ($override | is-not-empty) { $override } else { $env | get -o HOME | default "" }
}

def beat []: nothing -> nothing {
  let input = (payload)
  let probe = (^wakatime-cli --help | complete)
  if ($probe.stdout | str contains "--sync-ai-activity") == false {
    return
  }
  let home = (wakatime-home)
  if ($home | is-empty) {
    return
  }
  let state_dir = ([$home ".wakatime" "llm-assistants"] | path join)
  let plugin_id = (sanitize $PLUGIN_NAME $MAX_PLUGIN_CHARS)
  let state_file = (
    [$state_dir $"($plugin_id)-(sanitize (state-id $input) $MAX_ID_CHARS).wakatime"] | path join
  )
  let now = (date now | format date "%s" | into int)
  if (throttled $state_file $now) {
    return
  }
  let project = (text-field $input cwd)
  let args = (
    ["--sync-ai-activity" "--plugin" $PLUGIN_NAME]
    | append (if ($project | is-empty) { [] } else { ["--project-folder" $project] })
  )
  mkdir $state_dir
  ^$TIMEOUT $TOOL_TIMEOUT wakatime-cli ...$args | complete | ignore
  $"($now)\n" | save --force $state_file
}

def main [] {
  try { beat } catch { null }
}
