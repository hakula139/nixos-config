#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest
# ==================================================================================================
# Prints each day's agent sessions and commits on this host as JSON for the activity-report skill.
# Only prompts a person typed earn hours, so turns that notifications or agents start add none.
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

# A credential: a known token prefix, a 32+ character alphanumeric run holding a digit, or the value
# after `password:`
const SECRET = (
  [
    '\b(sk|ghp|gho|ghs|github_pat|glpat|xox[abp])[-_][A-Za-z0-9_-]{16,}'
    '(?<![A-Za-z0-9])(?=[A-Za-z]*[0-9])[A-Za-z0-9]{32,}(?![A-Za-z0-9])'
    '(?<kw>\b(?i:password|passwd)\s*[:=]\s*)\S+'
  ]
  | str join '|'
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
    | str replace --all --regex $SECRET '${kw}<redacted>'
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

def transcripts [pattern: string, since: datetime]: nothing -> list<string> {
  glob $pattern | where {|file| (ls $file | get 0.modified) >= $since }
}

# A transcript may end in a partial line while its session is still being written.
def read-transcript [file: string]: nothing -> list {
  let text = (open --raw $file)
  try {
    $text | from json --objects
  } catch {
    $text | lines | drop 1 | str join "\n" | from json --objects
  }
}

def session [tool: string, id: string, cwd: string, events: list]: nothing -> record {
  {
    tool: $tool
    id: $id
    cwd: $cwd
    events: ($events | update ts { into datetime | date to-timezone local })
  }
}

def claude-human [r: record]: nothing -> bool {
  let typed = (
    $r.toolUseResult? == null and $r.isMeta? != true and $r.isCompactSummary? != true
    and $r.isSidechain? != true and $r.teamName? == null
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

def claude-sessions [dir: string, since: datetime]: nothing -> list {
  transcripts ($dir | path join projects * *.jsonl) $since
  | each {|file|
    let records = (read-transcript $file)
    let cwd = ($records | get -o cwd | compact | get -o 0)
    let entrypoint = ($records | get -o entrypoint | compact | get -o 0 | default "")
    if $cwd == null or ($entrypoint | str starts-with "sdk") {
      return null
    }
    let events = (
      $records
      | each {|r|
        if $r.type == "user" and (claude-human $r) {
          {kind: prompt, ts: $r.timestamp, text: ($r.message.content | content-text)}
        } else if $r.type == "assistant" and $r.message.stop_reason? == "end_turn" {
          {kind: reply, ts: $r.timestamp, text: ($r.message.content | content-text)}
        }
      }
      | compact
    )
    session claude ($file | path parse | get stem) $cwd $events
  }
  | compact
}

def codex-sessions [dir: string, since: datetime]: nothing -> list {
  [($dir | path join sessions * * * *.jsonl) ($dir | path join archived_sessions *.jsonl)]
  | each {|pattern| transcripts $pattern $since }
  | flatten
  | each {|file|
    let records = (read-transcript $file)
    let meta = ($records | get -o 0.payload)
    # Desktop imports of other assistants' sessions, subagents, and reviewers carry other thread
    # sources, while `codex exec` and MCP runs are headless.
    if $meta.thread_source? != "user" or $meta.source? in [exec mcp] {
      return null
    }
    let events = (
      $records
      | where type == "event_msg"
      | each {|r|
        let p = $r.payload
        if $p.type == "item_completed" and $p.item.type? == "UserMessage" {
          {kind: prompt, ts: $r.timestamp, text: ($p.item.content | content-text)}
        } else if $p.type == "task_complete" and $p.last_agent_message? != null {
          {kind: reply, ts: $r.timestamp, text: $p.last_agent_message}
        }
      }
      | compact
    )
    session codex $meta.id $meta.cwd $events
  }
  | compact
}

def omp-sessions [dir: string, since: datetime]: nothing -> list {
  transcripts ($dir | path join sessions * *.jsonl) $since
  | each {|file|
    let records = (read-transcript $file)
    let meta = ($records | where type == "session" | first)
    let events = (
      $records
      | where type == "message"
      | each {|r|
        let m = $r.message
        if $m.role == "user" and $m.attribution? == "user" {
          {kind: prompt, ts: $r.timestamp, text: ($m.content | content-text)}
        } else if $m.role == "assistant" and $m.stopReason? == "stop" {
          {kind: reply, ts: $r.timestamp, text: ($m.content | content-text)}
        }
      }
      | compact
    )
    session omp $meta.id $meta.cwd $events
  }
}

# --------------------------------------------------------------------------------------------------
# Commits
# --------------------------------------------------------------------------------------------------

def commits [roots: list<string>, since: datetime]: nothing -> list {
  $roots
  | where ($it | path exists)
  | each {|root| ls $root | where type == dir | get name }
  | flatten
  | where ($it | path join .git | path exists)
  | each {|repo|
    let email = (^git -C $repo config user.email | complete | get stdout | str trim)
    if ($email | is-empty) {
      return []
    }
    (
      ^git -C $repo log --exclude=refs/stash --all --no-merges $"--author=($email)"
        $"--since=($since | format date '%+')" "--format=%aI%x09%s"
    )
    | lines
    | parse "{ts}\t{subject}"
    | each {|c|
      {cwd: $repo, ts: ($c.ts | into datetime | date to-timezone local), subject: $c.subject}
    }
  }
  | flatten
  # A rebase leaves the original commit reachable from another ref with the same author date.
  | uniq-by cwd ts subject
}

# --------------------------------------------------------------------------------------------------
# Days
# --------------------------------------------------------------------------------------------------

# A Claude Code worktree, `<repo>/.claude/worktrees/<name>`, reports work on its repository.
def project-of [cwd: string]: nothing -> string {
  $cwd | str replace --regex '/\.claude/worktrees/[^/]+.*$' '' | path basename
}

def context-of [cfg: record, project: string]: nothing -> string {
  if $project in $cfg.personalProjects { "personal" } else { $cfg.context }
}

def to-hours []: list<duration> -> float {
  math sum | $in / 1hr | math round --precision 2
}

# Credit each human prompt, across all sessions, with the time until its turn ends plus a reading
# allowance, cut short by the next prompt anywhere and capped per prompt.
def hours [cfg: record, prompts: list<record>]: nothing -> record {
  let timeline = ($prompts | sort-by ts)
  let credits = (
    $timeline
    | enumerate
    | each {|p|
      let until = [
        ($p.item.end + $cfg.readingMinutes * 1min)
        ($p.item.ts + $cfg.maxMinutes * 1min)
        ($timeline | get -o ($p.index + 1) | get -o ts)
      ]
      {project: $p.item.project, credit: (($until | compact | math min) - $p.item.ts)}
    }
  )
  {
    total: ($credits | get -o credit | append 0sec | to-hours)
    projects: ($credits | group-by project | update cells {|rows| $rows | get credit | to-hours })
  }
}

def stamp []: record -> record {
  {at: ($in.ts | format date "%H:%M"), text: ($in.text | excerpt)}
}

# A turn's final reply is the last one before the next prompt.
def final-replies []: list -> list {
  let events = $in
  $events
  | enumerate
  | where {|e|
    $e.item.kind == "reply" and ($events | get -o ($e.index + 1) | get -o kind) != "reply"
  }
  | get item
}

def day [cfg: record, start: datetime, sessions: list, commits: list]: nothing -> record {
  let end = ($start + 1day)
  let attended = (
    $sessions
    | each {|s|
      let prompts = ($s.events | where kind == "prompt" and ts >= $start and ts < $end)
      if ($prompts | is-empty) {
        return null
      }
      # Turns started today keep their replies past midnight, until the next prompt.
      let first = ($prompts | first | get ts)
      let next = ($s.events | where kind == "prompt" and ts >= $end | get -o 0.ts)
      let events = ($s.events | where {|e| $e.ts >= $first and ($next == null or $e.ts < $next) })
      let project = (project-of $s.cwd)
      let replies = ($s.events | where kind == "reply")
      # A turn ends at its first reply, so later turns that notifications start never extend it.
      let turns = (
        $prompts
        | each {|p|
          let ended = ($replies | where ts >= $p.ts | get -o 0.ts | default $p.ts)
          {ts: $p.ts, end: $ended, project: $project}
        }
      )
      {
        tool: $s.tool
        session: $s.id
        cwd: $s.cwd
        project: $project
        context: (context-of $cfg $project)
        prompts: ($prompts | each { stamp })
        replies: ($events | final-replies | each { stamp } | where text != "")
        turns: $turns
      }
    }
    | compact
    | sort-by {|s| $s.turns.0.ts }
  )
  {
    date: ($start | format date "%Y-%m-%d")
    weekday: ($start | format date "%a")
    hours: (hours $cfg ($attended | get -o turns | flatten))
    sessions: ($attended | reject turns)
    commits: (
      $commits
      | where ts >= $start and ts < $end
      | sort-by ts
      | each {|c|
        {at: ($c.ts | format date "%H:%M"), project: (project-of $c.cwd), subject: $c.subject}
      }
    )
  }
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Print the agent sessions and commits on this host for a range of local dates as JSON.
#
# For each day, a session lists its human prompts and the final reply of each turn. The day's hours
# credit each human prompt with the time until its turn ends plus a reading allowance, cut short by
# the next prompt in any session and capped per prompt, summed per project.
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
  let dirs = $cfg.assistantDirs
  # A Workmux worker takes its prompts from the agent that launched it.
  let sessions = (
    (claude-sessions $dirs.claude $since)
    ++ (codex-sessions $dirs.codex $since)
    ++ (omp-sessions $dirs.omp $since)
    | where cwd !~ '__worktrees/'
  )
  let commits = (commits $cfg.gitRoots $since)
  {
    context: $cfg.context
    days: ($days | each {|start| day $cfg $start $sessions $commits })
  }
  | to json
  | print
}
