#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest
# ==================================================================================================
# Prints each day's agent sessions on this host as JSON for the activity-report skill.
# Human hours credit only prompts a person typed, while agent hours cover every session's turns.
# ==================================================================================================

const EXCERPT_CHARS = 400

# Claude Code delivers these as user turns, though nobody typed them.
const CLAUDE_INJECTED = (
  [
    '^\s*<(local-command-|task-notification|teammate-message|system-reminder)'
    '^\s*Another Claude session sent a message:'
    '^\s*\[Request interrupted'
  ]
  | str join '|'
)

# Browser state that Codex Desktop prepends to a prompt
const BROWSER_CONTEXT = (
  '(?s)<in-app-browser-context.*?</in-app-browser-context>\s*(## My request:)?'
)

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

def excerpt []: string -> string {
  let flat = (
    $in
    | str replace --regex $BROWSER_CONTEXT ''
    | str replace --all --regex '\s+' ' '
    | str trim
  )
  if ($flat | str length --grapheme-clusters) > $EXCERPT_CHARS {
    $"($flat | str substring --grapheme-clusters 0..<$EXCERPT_CHARS)..."
  } else {
    $flat
  }
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

# A turn starts at any user message and ends at its first reply, so a later turn that a
# notification starts never extends an earlier one.
def turns [project: string]: list -> list {
  let events = $in
  let replies = ($events | where kind == "reply" | get ts)
  $events
  | where kind != "reply"
  | insert project $project
  | insert end {|e| $replies | where $it >= $e.ts | get -o 0 }
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
  | each {|file| do $parse (read-transcript $file) $file }
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
  let typed = (
    $r.isMeta? != true and $r.isCompactSummary? != true and $r.isSidechain? != true
    and $r.teamName? == null
  )
  if not $typed {
    return false
  }
  if $r.origin? != null {
    return ($r.origin.kind? == "human")
  }
  let text = ($r.message.content | content-text)
  ($text | is-not-empty) and not ($text =~ $CLAUDE_INJECTED)
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
        } else if $r.type == "assistant" and (claude-reply $r) {
          {kind: reply, ts: $r.timestamp, text: ($r.message.content | content-text)}
        }
      }
      | compact
    )
    let id = ($file | path parse | get stem)
    {id: $id, cwd: $cwd, attended: (not ($entrypoint | str starts-with "sdk")), events: $events}
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
        } else if $p.type == "item_completed" and $p.item.type? == "UserMessage" {
          {kind: prompt, ts: $r.timestamp, text: ($p.item.content | content-text)}
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
  read-sessions $cfg $since omp [sessions/*/*.jsonl] {|records|
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

def context-of [cfg: record, project: string]: nothing -> string {
  if $project in $cfg.personalProjects { "personal" } else { $cfg.context }
}

# Convert each project's time to hours, adding their total.
def tally []: record -> record {
  let hours = ($in | update cells { $in / 1hr })
  {
    total: ($hours | values | append 0.0 | math sum | math round --precision 2)
    projects: ($hours | update cells { math round --precision 2 })
  }
}

# Credit each human prompt, across all sessions, with the time until its turn ends plus a reading
# allowance, cut short by the next prompt anywhere and capped per prompt.
def human-hours [cfg: record, prompts: list<record>]: nothing -> record {
  let timeline = ($prompts | sort-by ts)
  $timeline
  | enumerate
  | each {|p|
    let until = [
      (($p.item.end | default $p.item.ts) + $cfg.readingMinutes * 1min)
      ($p.item.ts + $cfg.maxMinutes * 1min)
      ($timeline | get -o ($p.index + 1) | get -o ts)
    ]
    {project: $p.item.project, credit: (($until | compact | math min) - $p.item.ts)}
  }
  | group-by project
  | update cells { get credit | math sum }
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
  | update cells { covered }
  | tally
}

def stamp []: record -> record {
  {at: ($in.ts | format date "%H:%M"), text: ($in.text | excerpt)}
}

# A turn's final reply is the last one before the next prompt.
def final-replies []: list -> list {
  let events = ($in | where kind != "trigger")
  $events
  | enumerate
  | where {|e|
    $e.item.kind == "reply" and ($events | get -o ($e.index + 1) | get -o kind) != "reply"
  }
  | get item
}

def day [cfg: record, start: datetime, sessions: list]: nothing -> record {
  let end = ($start + 1day)
  let attended = (
    $sessions
    | where attended
    | each {|s|
      let prompts = ($s.turns | where kind == "prompt" and ts >= $start and ts < $end)
      if ($prompts | is-empty) {
        return null
      }
      # Turns started today keep their replies past midnight, until the next prompt.
      let first = ($prompts | first | get ts)
      let next = ($s.turns | where kind == "prompt" and ts >= $end | get -o 0.ts)
      let events = ($s.events | where {|e| $e.ts >= $first and ($next == null or $e.ts < $next) })
      {
        tool: $s.tool
        session: $s.id
        cwd: $s.cwd
        project: $s.project
        context: (context-of $cfg $s.project)
        prompts: $prompts
        replies: ($events | final-replies | each { stamp } | where text != "")
      }
    }
    | compact
    | sort-by {|s| $s.prompts.0.ts }
  )
  {
    date: ($start | format date "%Y-%m-%d")
    weekday: ($start | format date "%a")
    hours: {
      human: (human-hours $cfg ($attended | get -o prompts | flatten))
      agent: (agent-hours $cfg $start ($sessions | get -o turns | flatten))
    }
    sessions: ($attended | update prompts { each { stamp } })
  }
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Print the agent sessions on this host for a range of local dates as JSON.
#
# For each day, a session lists its human prompts and the final reply of each turn. Human hours
# credit each human prompt with the time until its turn ends plus a reading allowance, cut short by
# the next prompt in any session and capped per prompt, summed per project. Agent hours union each
# project's turns in every session, from any user message to its reply and capped per turn.
def main [
  config_file: string # JSON with the host's context, policy, and source directories
  from: string # First local date, as YYYY-MM-DD
  to?: string # Last local date, as YYYY-MM-DD, the first date by default
]: nothing -> nothing {
  let cfg = (open $config_file)
  let to = ($to | default $from)
  if $to < $from {
    error make {msg: $"Last date ($to) precedes first date ($from)"}
  }
  let days = (seq date --begin-date $from --end-date $to | each { into datetime })
  let since = ($days | first)
  let sessions = (
    (claude-sessions $cfg $since) ++ (codex-sessions $cfg $since) ++ (omp-sessions $cfg $since)
  )
  {
    context: $cfg.context
    days: ($days | each {|start| day $cfg $start $sessions })
  }
  | to json
  | print
}
