#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest
# ==================================================================================================
# Prints each day's agent sessions on this host as JSON for the activity-report skill.
# Human hours credit only prompts a person typed, while agent hours cover every session's turns.
# ==================================================================================================

# Mirrors how Codex Desktop extracts the request from a prompt.
const REQUEST_HEADING = '## My request( for Codex)?:'

# --------------------------------------------------------------------------------------------------
# Text
# --------------------------------------------------------------------------------------------------

# A message's content is a string or a list of typed parts, of which only text parts carry text.
def content-text []: any -> string {
  let content = $in
  if ($content | describe) == "string" {
    $content
  } else {
    $content | default [] | get -o text | compact | str join "\n"
  }
}

def excerpt [chars: int]: string -> string {
  let flat = (
    $in
    | str replace --all --regex '\s+' ' '
    | str trim
  )
  if ($flat | str length --grapheme-clusters) > $chars {
    $"($flat | str substring --grapheme-clusters 0..<$chars)..."
  } else {
    $flat
  }
}

def strip-request-prefix []: string -> string {
  let text = $in
  let parts = ($text | split row --regex $REQUEST_HEADING)
  if ($parts | length) == 1 { $text } else { $parts | last | str trim }
}

# --------------------------------------------------------------------------------------------------
# Transcripts
# --------------------------------------------------------------------------------------------------

# A transcript may end in a partial line while its session is still being written.
def read-transcript [file: string]: nothing -> list {
  let text = (open --raw $file)
  try {
    $text | from json --objects
  } catch {
    $text | lines | drop 1 | str join "\n" | from json --objects
  }
}

# Match starts to their first subsequent reply, stopping at an explicit cancellation.
def turns [project: string]: list -> list {
  $in
  | reverse
  | generate {|event, nextReply: oneof<datetime, nothing> = null|
    match $event.kind {
      reply => {next: $event.ts}
      abort => {next: null}
      _ => {out: ($event | merge {project: $project, end: $nextReply}), next: $nextReply}
    }
  }
  | reverse
}

# Read the tool's transcripts that match the globs and changed since the date as sessions. The
# parser maps a transcript's records and file to `id`, `cwd`, `attended`, and `events`, or to null
# to skip it. Only an attended session's prompts earn human hours.
def read-sessions [
  cfg: record
  since: datetime
  tool: string
  globs: list<string>
  parse: closure
]: nothing -> list {
  $globs
  | each {|pattern| glob ($cfg.assistantDirs | get $tool | path join $pattern) }
  | flatten
  | where {|file| (ls $file | get 0.modified) >= $since }
  | each {|file|
    let session = (do $parse (read-transcript $file) $file)
    if $session != null { $session | insert transcript $file }
  }
  | compact
  | each {|s|
    let project = (project-of $cfg $s.cwd)
    let events = ($s.events | update ts { into datetime | date to-timezone local })
    $s | merge {
      tool: $tool
      project: $project
      attended: ($s.attended and ($cfg.excludedDirs | all {|pattern| $s.cwd !~ $pattern }))
      events: $events
      turns: ($events | turns $project)
    }
  }
}

def claude-human [r: record]: nothing -> bool {
  $r.origin?.kind? == "human"
}

# Subagents end their run with a SubagentHandback call in place of a final text reply.
def claude-reply [r: record]: nothing -> bool {
  $r.message.stop_reason? == "end_turn" or "SubagentHandback" in ($r.message.content | get -o name)
}

def claude-sessions [cfg: record, since: datetime]: nothing -> list {
  let globs = [projects/*/*.jsonl projects/*/*/subagents/*.jsonl]
  read-sessions $cfg $since claude $globs {|records, file|
    let cwd = ($records | get -o cwd | compact | get -o 0)
    if $cwd == null {
      return null
    }
    let entrypoint = ($records | get -o entrypoint | compact | get -o 0 | default "")
    let events = (
      $records
      | each {|r|
        if $r.type == "user" and $r.toolUseResult? == null {
          let kind = if (claude-human $r) { "prompt" } else { "trigger" }
          {kind: $kind, ts: $r.timestamp, text: ($r.message.content | content-text)}
        } else if (
          $r.type == "attachment"
          and $r.attachment.type? == "queued_command"
          and (claude-human $r.attachment)
        ) {
          {kind: prompt, ts: $r.timestamp, text: ($r.attachment.prompt | content-text)}
        } else if $r.type == "assistant" and (claude-reply $r) {
          {kind: reply, ts: $r.timestamp, text: ($r.message.content | content-text)}
        }
      }
      | compact
    )
    let id = ($file | path parse | get stem)
    let attended = (
      (not ($entrypoint | str starts-with "sdk")) and ($records.0.isSidechain? != true)
    )
    {id: $id, cwd: $cwd, attended: $attended, events: $events}
  }
}

def codex-sessions [cfg: record, since: datetime]: nothing -> list {
  read-sessions $cfg $since codex [sessions/*/*/*/*.jsonl archived_sessions/*.jsonl] {|records|
    let meta = ($records | get -o 0.payload)
    # Codex Desktop imports of other assistants' sessions carry no thread source.
    if $meta.thread_source? == null {
      return null
    }
    let events = (
      $records
      | where type == "event_msg"
      | each {|r|
        let p = $r.payload
        if $p.type == "task_started" {
          {kind: trigger, ts: $r.timestamp, text: ""}
        } else if $p.type == "turn_aborted" {
          {kind: abort, ts: $r.timestamp}
        } else if $p.type == "item_completed" and $p.item.type? == "UserMessage" {
          let text = ($p.item.content | content-text | strip-request-prefix)
          {kind: prompt, ts: $r.timestamp, text: $text}
        } else if $p.type == "task_complete" and $p.last_agent_message? != null {
          {kind: reply, ts: $r.timestamp, text: $p.last_agent_message}
        }
      }
      | compact
    )
    # Subagents and reviewers carry other thread sources. `codex exec` and MCP runs are headless.
    let attended = ($meta.thread_source == "user" and $meta.source? not-in [exec mcp])
    {id: $meta.id, cwd: $meta.cwd, attended: $attended, events: $events}
  }
}

def omp-sessions [cfg: record, since: datetime]: nothing -> list {
  read-sessions $cfg $since omp [sessions/**/*.jsonl] {|records|
    let meta = ($records | where type == "session" | first)
    let events = (
      $records
      | where type == "message"
      | each {|r|
        let m = $r.message
        if $m.role == "user" {
          let kind = if $m.attribution? == "user" { "prompt" } else { "trigger" }
          {kind: $kind, ts: $r.timestamp, text: ($m.content | content-text)}
        } else if $m.role == "assistant" and $m.stopReason? == "stop" {
          {kind: reply, ts: $r.timestamp, text: ($m.content | content-text)}
        }
      }
      | compact
    )
    {id: $meta.id, cwd: $meta.cwd, attended: true, events: $events}
  }
}

# --------------------------------------------------------------------------------------------------
# Days
# --------------------------------------------------------------------------------------------------

def project-of [cfg: record, cwd: string]: nothing -> string {
  $cfg.worktreePatterns
  | reduce --fold $cwd {|pattern, dir| $dir | str replace --regex $pattern '' }
  | path basename
}

def tally []: record -> record {
  {
    total: ($in | values | append 0.0 | math sum | math round --precision 2)
    projects: ($in | update cells { math round --precision 2 })
  }
}

# Each prompt with the hours it earned, rounded to 0.0001.
def credit-prompts [cfg: record]: list -> list<record> {
  let timeline = (
    $in
    | where attended
    | each {|s| $s.turns | where kind == "prompt" | insert transcript $s.transcript }
    | flatten
    | sort-by ts
  )
  $timeline
  | enumerate
  | each {|p|
    let until = [
      (($p.item.end | default $p.item.ts) + $cfg.readingMinutes * 1min)
      ($p.item.ts + $cfg.maxMinutes * 1min)
      ($timeline | get -o ($p.index + 1) | get -o ts)
    ]
    let hours = ((($until | compact | math min) - $p.item.ts) / 1hr)
    $p.item | insert hours ($hours | math round --precision 4)
  }
}

def human-hours []: list<record> -> record {
  $in
  | group-by project
  | update cells { get hours | math sum }
  | tally
}

# Time covered by a list of spans, counting overlaps once
def covered []: list<record> -> duration {
  let spans = ($in | sort-by from)
  $spans
  | reduce --fold {total: 0sec, until: $spans.0.from} {|span, acc|
    let added = ([($span.to - ([$span.from $acc.until] | math max)) 0sec] | math max)
    {total: ($acc.total + $added), until: ([$span.to $acc.until] | math max)}
  }
  | get total
}

# Union each project's turns that got a reply, capped per turn and clipped to the day, so parallel
# sessions count once.
def agent-hours [cfg: record, start: datetime, turns: list<record>]: nothing -> record {
  let end = ($start + 1day)
  $turns
  | where end != null
  | each {|t|
    let to = ([$t.end ($t.ts + $cfg.agentMaxMinutes * 1min) $end] | math min)
    {project: $t.project, from: ([$t.ts $start] | math max), to: $to}
  }
  | where {|span| $span.to > $span.from }
  | group-by project
  | update cells {|cell| ($cell | covered) / 1hr }
  | tally
}

def stamp [excerpt_chars: int]: record -> record {
  let event = $in
  {
    at: ($event.ts | format date "%H:%M")
    text: (if $excerpt_chars == 0 { $event.text } else { $event.text | excerpt $excerpt_chars })
  }
}

# A turn's final reply is the last one before the next prompt.
def final-replies []: list -> list {
  let events = ($in | where kind not-in [trigger abort])
  $events
  | enumerate
  | where {|e|
    $e.item.kind == "reply" and ($events | get -o ($e.index + 1) | get -o kind) != "reply"
  }
  | get item
}

def day [
  cfg: record
  start: datetime
  sessions: list
  credited: list
  excerpt_chars: int
]: nothing -> record {
  let end = ($start + 1day)
  let today = ($credited | where ts >= $start and ts < $end)
  {
    date: ($start | format date "%Y-%m-%d")
    weekday: ($start | format date "%a")
    hours: {
      human: ($today | human-hours)
      agent: (agent-hours $cfg $start ($sessions | get -o turns | flatten))
    }
    sessions: (
      $today
      | get transcript
      | uniq
      | each {|transcript|
        let s = ($sessions | where transcript == $transcript | first)
        let prompts = ($today | where transcript == $transcript)
        # Turns started today keep their replies past midnight, until the next prompt.
        let first = ($prompts | first | get ts)
        let next = ($s.turns | where kind == "prompt" and ts >= $end | get -o 0.ts)
        let events = ($s.events | where {|e| $e.ts >= $first and ($next == null or $e.ts < $next) })
        {
          tool: $s.tool
          session: $s.id
          transcript: $s.transcript
          cwd: $s.cwd
          project: $s.project
          prompts: ($prompts | each {|p| $p | stamp $excerpt_chars | insert hours $p.hours })
          replies: ($events | final-replies | each { stamp $excerpt_chars } | where text != "")
        }
      }
    )
  }
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Print the agent sessions on this host for a range of local dates as JSON.
#
# Each day lists its sessions with their transcript, project, the prompts a person typed with the
# human hours each earned, and the final reply of each turn. Human hours credit each prompt with
# the time until its turn ends plus a reading allowance, cut short by the next prompt in any
# session and capped per prompt. Agent hours union each project's turns in every session, from any
# user message to its reply and capped per turn. The top-level `labels` gives each project's labels
# and the default for unlisted projects.
def main [
  config_file: string # JSON with the host's labels, policy, and source directories
  from: string # First local date, as YYYY-MM-DD
  to?: string # Last local date, as YYYY-MM-DD, the first date by default
  --excerpt-chars: int = 400 # Characters kept per prompt and reply, or 0 to keep the text whole
]: nothing -> nothing {
  let cfg = (open $config_file)
  let to = ($to | default $from)
  if $to < $from {
    error make {msg: $"Last date ($to) precedes first date ($from)"}
  }
  if $excerpt_chars < 0 {
    error make {msg: $"Excerpt length ($excerpt_chars) must be 0 or greater"}
  }
  let days = (seq date --begin-date $from --end-date $to | each { into datetime })
  let since = ($days | first)
  let sessions = (
    (claude-sessions $cfg $since) ++ (codex-sessions $cfg $since) ++ (omp-sessions $cfg $since)
  )
  let prompts = ($sessions | credit-prompts $cfg)
  {
    labels: $cfg.labels
    days: ($days | each {|start| day $cfg $start $sessions $prompts $excerpt_chars })
  }
  | to json
  | print
}
