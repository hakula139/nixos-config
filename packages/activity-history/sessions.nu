# ==================================================================================================
# Activity History Sessions
# ==================================================================================================

use common.nu *

# Read a session file, which may end in a partial line while the session is still being written.
def read-session [file: string]: nothing -> list {
  let text = if ($file | str ends-with ".zst") { ^zstdcat $file } else { open --raw $file }
  try {
    $text | from json --objects
  } catch {
    $text | lines | drop 1 | str join "\n" | from json --objects
  }
}

# Session records stamp UTC ISO strings, which compare in time order.
def iso-bounds [bounds: record]: nothing -> record {
  {start: (utc-iso $bounds.start), end: (utc-iso $bounds.end)}
}

def recent-sessions [dir: string, bounds: record]: nothing -> list<string> {
  glob $"($dir)/*/*.jsonl" | where {|file| (ls $file | get 0.modified) >= $bounds.start }
}

# A message's content is a string or a list of typed parts, of which only text parts carry text.
def content-text []: any -> string {
  let content = $in
  if ($content | describe) == "string" {
    $content
  } else {
    $content | get -o text | compact | str join "\n"
  }
}

# A final message without text, such as a thinking block, still ends the turn.
def reply-or-end [text: string]: nothing -> record {
  if ($text | is-empty) { {k: end} } else { {k: reply, text: $text} }
}

# Claude Code injects slash commands and teammate messages as user turns.
const CLAUDE_INJECTED = (
  '^\s*(<(command-name|local-command-|task-notification|teammate-message|system-reminder)'
  + '|Another Claude session sent a message:)'
)

def claude-human [r: record]: nothing -> bool {
  let typed = (
    $r.type == "user" and $r.toolUseResult? == null and $r.isMeta? != true
    and $r.isCompactSummary? != true and $r.isSidechain? != true
    and $r.agentName? == null and $r.teamName? == null
    and ($r.origin?.kind? | default "human") == "human"
  )
  if not $typed {
    return false
  }
  let text = ($r.message.content | content-text)
  ($text | is-not-empty) and not ($text =~ $CLAUDE_INJECTED)
}

def claude-records [records: list, bounds: record]: nothing -> list {
  let day = (iso-bounds $bounds)
  $records
  | each {|r|
    let at = {ts: $r.timestamp?, cwd: $r.cwd?, entrypoint: $r.entrypoint?}
    if $r.type == "ai-title" {
      {k: title, text: $r.aiTitle}
    } else if not ($r.timestamp? | within $day) {
      null
    } else if (claude-human $r) {
      $at | merge {k: prompt, text: ($r.message.content | content-text)}
    } else if $r.type == "system" and $r.subtype? == "turn_duration" {
      $at | merge {k: end}
    } else if $r.type == "assistant" and $r.message.stop_reason? == "end_turn" {
      $at | merge (reply-or-end ($r.message.content | content-text))
    }
  }
  | compact
}

def codex-records [records: list, bounds: record]: nothing -> list {
  let day = (iso-bounds $bounds)
  $records
  | where type == "event_msg" and ($it.timestamp | within $day)
  | each {|r|
    let p = $r.payload
    match $p.type {
      "item_completed" if $p.item.type == "UserMessage" => {
        {k: prompt, ts: $r.timestamp, text: ($p.item.content | content-text)}
      }
      "user_message" => { {k: prompt, ts: $r.timestamp, text: $p.message} }
      "task_complete" => { {k: reply, ts: $r.timestamp, text: $p.last_agent_message} }
      _ => null
    }
  }
  | compact
}

def omp-records [records: list, bounds: record]: nothing -> list {
  let day = (iso-bounds $bounds)
  $records
  | each {|r|
    if $r.type == "session" {
      {k: cwd, cwd: $r.cwd}
    } else if $r.type == "title" {
      {k: title, text: $r.title}
    } else if $r.type == "message" and ($r.timestamp | within $day) {
      let text = ($r.message.content | content-text)
      if $r.message.role == "user" and $r.message.attribution? == "user" {
        {k: prompt, ts: $r.timestamp, text: $text}
      } else if $r.message.role == "assistant" and $r.message.stopReason? == "stop" {
        {ts: $r.timestamp} | merge (reply-or-end $text)
      } else if $r.message.role == "assistant" {
        {k: end, ts: $r.timestamp}
      }
    }
  }
  | compact
}

def session-events [
  cfg: record
  source: string
  session: string
  records: list
  base: record
]: nothing -> list {
  let title = ($records | where k == "title" | get -o 0.text)
  $records
  | where k in [prompt end reply]
  | each {|r|
    {
      id: $"($source):($session):($r.k):($r.ts)"
      host: $cfg.host
      source: $source
      kind: $r.k
      ts: $r.ts
      session: $session
      cwd: ($r.cwd? | default $base.cwd)
      mode: $base.mode
      title: ($title | excerpt)
      text: ($r.text? | excerpt)
    }
  }
}

export def collect-claude [cfg: record, bounds: record]: nothing -> list {
  recent-sessions ($nu.home-dir | path join ".claude" "projects") $bounds
  | each {|file|
    let records = (claude-records (read-session $file) $bounds)
    let first = ($records | where k != "title" | get -o 0)
    if $first == null {
      return []
    }
    let mode = if $first.entrypoint? == "sdk-cli" { "automated" } else { "interactive" }
    let session = ($file | path parse | get stem)
    session-events $cfg claude $session $records {cwd: $first.cwd, mode: $mode}
  }
  | flatten
}

const THREADS_QUERY = "
  select id, rollout_path, source, originator, cwd, title from threads
  where thread_source = 'user' and updated_at >= ? and created_at < ?
"

export def collect-codex [cfg: record, bounds: record]: nothing -> list {
  let home = ($nu.home-dir | path join ".codex")
  let db = ($home | path join "state_5.sqlite")
  if not ($db | path exists) {
    return []
  }
  let start = ($bounds.start | into int) // 1_000_000_000
  let end = ($bounds.end | into int) // 1_000_000_000
  open $db
  | query db $THREADS_QUERY --params [$start $end]
  | each {|thread|
    let name = ($thread.rollout_path | path basename)
    let archived = ($home | path join "archived_sessions" $"($name).zst")
    let file = ([$thread.rollout_path $archived] | where ($it | path exists) | get -o 0)
    if $file == null {
      return []
    }
    let records = (
      codex-records (read-session $file) $bounds | append {k: "title", text: $thread.title}
    )
    let mode = if $thread.source in [exec mcp] or $thread.originator == "codex_exec" {
      "automated"
    } else {
      "interactive"
    }
    session-events $cfg codex $thread.id $records {cwd: $thread.cwd, mode: $mode}
  }
  | flatten
}

export def collect-omp [cfg: record, bounds: record]: nothing -> list {
  recent-sessions ($nu.home-dir | path join ".omp" "agent" "sessions") $bounds
  | each {|file|
    let records = (omp-records (read-session $file) $bounds)
    let cwd = ($records | where k == "cwd" | get 0.cwd)
    let session = ($file | path parse | get stem)
    session-events $cfg omp $session $records {cwd: $cwd, mode: "interactive"}
  }
  | flatten
}
