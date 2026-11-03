#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest
# ==================================================================================================
# Prints each day's agent sessions on this host as JSON for the activity-report skill.
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

# Cut text to a number of characters, or keep it whole when the number is zero.
def excerpt [chars: int]: string -> string {
  let text = $in
  if $chars == 0 {
    $text
  } else {
    let flat = (
      $text
      | str replace --all --regex '\s+' ' '
      | str trim
    )
    if ($flat | str length --grapheme-clusters) > $chars {
      $"($flat | str substring --grapheme-clusters 0..<$chars)..."
    } else {
      $flat
    }
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
  let text = (
    if ($file | str ends-with ".zst") { ^zstd -dc $file } else { open --raw $file }
  )
  try {
    $text | from json --objects
  } catch {
    $text | lines | drop 1 | str join "\n" | from json --objects
  }
}

# Give each start its first subsequent reply, or its last model output before the next start, and
# collect the files written until that start. A write therefore belongs to the latest start before
# it in its own session. A turn holds a prompt or model output, so a start with only a local
# command is dropped, and a turn with neither reply nor model output ends where it started.
def turns []: list -> list {
  $in
  | reverse
  | generate {|event, state: record = {
      reply: null
      start: null
      paths: []
      cut: null
      model: null
    }|
    match $event.kind {
      reply => {next: ($state | update reply $event.ts)}
      abort => {next: ($state | update reply null)}
      write => {next: ($state | update paths { append $event.paths })}
      model => {next: ($state | update model ($state.model | default $event.ts))}
      pause => {next: ($state | update cut $event.ts)}
      _ => {
        let turn = ($event | merge {
          end: ($state.reply | default $state.model | default $event.ts)
          paths: $state.paths
          idle: ($state.cut | default $state.start)
        })
        let kept = ($event.kind == "prompt" or $state.model != null)
        let next = {
          reply: $state.reply
          start: $event.ts
          paths: []
          cut: null
          model: null
        }
        if $kept { {out: $turn, next: $next} } else { {next: $next} }
      }
    }
  }
  | reverse
}

# Read the tool's transcripts that match the globs and changed since the date as sessions. The
# parser maps a transcript's records and file to `id`, `cwd`, `attended`, `parent`, and `events`,
# or to null to skip it. A turn's span stops at its last record before a gap longer than
# `agentIdleMinutes`, or at its next start. Only an attended session's prompts earn human hours.
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
  | each {|file| {file: $file, stem: ($file | str replace --regex '\.zst$' '')} }
  | uniq-by stem
  | get file
  | par-each --keep-order {|file|
    let records = (read-transcript $file)
    let session = (do $parse $records $file)
    if $session == null {
      null
    } else {
      let gap = ($cfg.agentIdleMinutes * 1min)
      let pauses = (
        $records
        | get -o timestamp
        | compact
        | into datetime
        | sort
        | window 2
        | where {|w| ($w.1 - $w.0) > $gap }
        | each {|w| {kind: pause, ts: $w.0} }
      )
      $session | insert transcript $file | update events { append $pauses }
    }
  }
  | par-each --keep-order {|s|
    let events = (
      $s.events
      | update ts { into datetime | date to-timezone local }
      | sort-by ts
      | each {|e|
        if $e.kind == "write" { $e | update paths { each {|path| physical $path } } } else { $e }
      }
    )
    $s | merge {
      tool: $tool
      attended: ($s.attended and ($cfg.excludedDirs | all {|pattern| $s.cwd !~ $pattern }))
      events: $events
      turns: ($events | turns)
    }
  }
}

# The transcript of the session that delegated to a Claude session, or null. A subagent names its
# parent agent, and otherwise its lead. A teammate names its lead's session id.
def claude-parent [cfg: record, records: list, file: string]: nothing -> any {
  let dir = ($file | path dirname)
  if ($dir | path basename) == "subagents" {
    let meta_file = ($file | str replace --regex '\.jsonl$' '.meta.json')
    let meta = (open --raw $meta_file | from json)
    let parent_agent = ($meta | get -o parentAgentId)
    if $parent_agent != null {
      $dir | path join $"agent-($parent_agent).jsonl"
    } else {
      $"($dir | path dirname).jsonl"
    }
  } else {
    let team = ($records | get -o teamName | compact | get -o 0)
    if $team == null or not ($team | str starts-with "session-") {
      null
    } else {
      let id = ($team | str replace "session-" "")
      glob $"($cfg.assistantDirs.claude)/projects/*/($id)*.jsonl" | get -o 0
    }
  }
}

def claude-human [r: record]: nothing -> bool {
  $r.origin?.kind? == "human"
}

# A question's answers become a prompt, one `question: answer` line per entry.
def claude-question [r: record]: nothing -> any {
  let result = $r.toolUseResult?
  if not ($result | describe | str starts-with "record") {
    return null
  }
  let answers = ($result | get -o answers | default {})
  if ($answers | is-empty) {
    null
  } else {
    let text = ($answers | items {|question, answer| $"($question): ($answer)" } | str join "\n")
    {kind: prompt, ts: $r.timestamp, text: $text}
  }
}

# Subagents end their run with a SubagentHandback call in place of a final text reply.
def claude-reply [r: record]: nothing -> bool {
  $r.message.stop_reason? == "end_turn" or "SubagentHandback" in ($r.message.content | get -o name)
}

# Absolute paths a Claude record wrote: Edit and Write name a file, NotebookEdit a notebook.
def claude-writes [r: record]: nothing -> list<string> {
  let part = ($r.message.content | get -o 0)
  if $part == null or $part.type? != "tool_use" or $part.name not-in [Edit Write NotebookEdit] {
    return []
  }
  if $part.name == "NotebookEdit" {
    [$part.input.notebook_path] | compact
  } else {
    [$part.input.file_path] | compact
  }
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
        let event = (
          if $r.isCompactSummary? == true {
            null
          } else if $r.type == "user" and $r.toolUseResult? == null {
            let kind = if (claude-human $r) { "prompt" } else { "trigger" }
            {kind: $kind, ts: $r.timestamp, text: ($r.message.content | content-text)}
          } else if (
            $r.type == "attachment"
            and $r.attachment.type? == "queued_command"
            and (claude-human $r.attachment)
          ) {
            {kind: prompt, ts: $r.timestamp, text: ($r.attachment.prompt | content-text)}
          } else if $r.type == "user" {
            claude-question $r
          } else if $r.type == "assistant" {
            let paths = (claude-writes $r)
            if ($paths | is-not-empty) {
              {kind: write, ts: $r.timestamp, paths: $paths}
            } else if (claude-reply $r) {
              {kind: reply, ts: $r.timestamp, text: ($r.message.content | content-text)}
            }
          }
        )
        let model = (
          if $r.type == "assistant" or $r.isCompactSummary? == true {
            {kind: model, ts: $r.timestamp}
          }
        )
        [$event $model]
      }
      | flatten
      | compact
    )
    let id = ($file | path parse | get stem)
    let headless = ($entrypoint | str starts-with "sdk")
    let attended = ((not $headless) and ($records.0.isSidechain? != true))
    {
      id: $id
      cwd: $cwd
      attended: $attended
      parent: (claude-parent $cfg $records $file)
      events: $events
    }
  }
}

# The transcript of the thread that delegated to a Codex session, or null. Subagents and guardian
# reviews both carry `parent_thread_id` at the top level of the session metadata.
def codex-parent [cfg: record, meta: record]: nothing -> any {
  let id = ($meta | get -o parent_thread_id)
  if $id == null {
    null
  } else {
    let base = $cfg.assistantDirs.codex
    (
      (glob $"($base)/sessions/*/*/*/rollout-*-($id).jsonl")
      ++ (glob $"($base)/sessions/*/*/*/rollout-*-($id).jsonl.zst")
      ++ (glob $"($base)/archived_sessions/rollout-*-($id).jsonl")
      ++ (glob $"($base)/archived_sessions/rollout-*-($id).jsonl.zst")
    )
    | get -o 0
  }
}

def codex-sessions [cfg: record, since: datetime]: nothing -> list {
  read-sessions $cfg $since codex [
    sessions/*/*/*/*.jsonl
    sessions/*/*/*/*.jsonl.zst
    archived_sessions/*.jsonl
    archived_sessions/*.jsonl.zst
  ] {|records|
    let meta = ($records | get -o 0.payload)
    # Codex Desktop imports of other assistants' sessions carry no thread source.
    if $meta.thread_source? == null {
      return null
    }
    let events = (
      $records
      | each {|r|
        let event = (
          if $r.type != "event_msg" {
            null
          } else {
            let p = $r.payload
            if $p.type == "task_started" {
              {kind: trigger, ts: $r.timestamp, text: ""}
            } else if $p.type == "turn_aborted" {
              {kind: abort, ts: $r.timestamp}
            } else if $p.type == "item_completed" and $p.item.type? == "UserMessage" {
              let text = ($p.item.content | content-text | strip-request-prefix)
              {kind: prompt, ts: $r.timestamp, text: $text}
            } else if $p.type == "item_completed" and $p.item.type? == "FileChange" {
              {kind: write, ts: $r.timestamp, paths: ($p.item.changes? | default {} | columns)}
            } else if $p.type == "task_complete" and $p.last_agent_message? != null {
              {kind: reply, ts: $r.timestamp, text: $p.last_agent_message}
            }
          }
        )
        let model = (
          if (
            $r.type == "response_item"
            and (
              $r.payload.type? in [agent_message reasoning function_call custom_tool_call]
              or $r.payload.type? == "compaction"
              or $r.payload.role? == "assistant"
            )
          ) {
            {kind: model, ts: $r.timestamp}
          }
        )
        [$event $model]
      }
      | flatten
      | compact
    )
    # Subagents and reviewers carry other thread sources. `codex exec` and MCP runs are headless.
    let attended = ($meta.thread_source == "user" and $meta.source? not-in [exec mcp])
    {
      id: $meta.id
      cwd: $meta.cwd
      attended: $attended
      parent: (codex-parent $cfg $meta)
      events: $events
    }
  }
}

# An OMP call writes one path, and its patch form names a path per `[<path>#<hash>]` header.
def omp-paths [cwd: string, call: record]: nothing -> list<string> {
  let args = ($call.arguments | default {})
  let paths = (
    [($args.path?)]
    ++ (
      if $args.input? == null { [] } else {
        $args.input | lines | parse --regex '^\[\s*(?<path>.+?)#\w+\s*\]$' | get path
      }
    )
  )
  $paths | compact | each {|path| $cwd | path join $path | path expand --no-symlink }
}

def omp-sessions [cfg: record, since: datetime]: nothing -> list {
  read-sessions $cfg $since omp [sessions/**/*.jsonl] {|records, file|
    let meta = ($records | where type == "session" | first)
    let cwd = $meta.cwd
    let events = (
      $records
      | each {|r|
        let event = (
          if $r.type != "message" {
            null
          } else {
            let m = $r.message
            if $m.role == "user" {
              let kind = if $m.attribution? == "user" { "prompt" } else { "trigger" }
              {kind: $kind, ts: $r.timestamp, text: ($m.content | content-text)}
            } else if $m.role == "assistant" and $m.stopReason? == "stop" {
              {kind: reply, ts: $r.timestamp, text: ($m.content | content-text)}
            } else if $m.role == "assistant" {
              let paths = (
                $m.content
                | where {|part| $part.type? == "toolCall" and $part.name in [write edit] }
                | each {|part| omp-paths $cwd $part }
                | flatten
              )
              if ($paths | is-not-empty) {
                {kind: write, ts: $r.timestamp, paths: $paths}
              }
            }
          }
        )
        let model = (
          if $r.type == "message" and $r.message.role? == "assistant" {
            {kind: model, ts: $r.timestamp}
          }
        )
        [$event $model]
      }
      | flatten
      | compact
    )
    {
      id: $meta.id
      cwd: $cwd
      attended: true
      parent: $"($file | path dirname).jsonl"
      events: $events
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Repositories
# --------------------------------------------------------------------------------------------------

# The nearest existing ancestor of a directory, since a deleted worktree no longer exists.
def existing-ancestor [dir: string]: nothing -> any {
  if ($dir | path exists) {
    $dir
  } else {
    let parent = ($dir | path dirname)
    if $parent == $dir { null } else { existing-ancestor $parent }
  }
}

# The repository at a directory, as its checkout and root, or null outside any repository. A linked
# worktree's root is its main checkout, the parent of the worktree's common git dir.
def repository-of [dir: string]: nothing -> any {
  let run = (
    ^git -C $dir rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel
    | complete
  )
  if $run.exit_code != 0 {
    null
  } else {
    let parts = ($run.stdout | lines)
    {
      checkout: $parts.2
      root: (if $parts.0 == $parts.1 { $parts.2 } else { $parts.1 | path dirname })
    }
  }
}

# The repository holding each directory, keyed by directory. Resolving each ancestor once is the
# cache, and a missing directory resolves through its nearest existing ancestor.
def repository-map [dirs: list<string>]: nothing -> record {
  let pairs = ($dirs | each {|dir| {dir: $dir, ancestor: (existing-ancestor $dir)} })
  let found = (
    $pairs
    | get ancestor
    | compact
    | uniq
    | reduce --fold {} {|ancestor, acc| $acc | insert $ancestor (repository-of $ancestor) }
  )
  $pairs | reduce --fold {} {|pair, acc| $acc | insert $pair.dir ($found | get -o $pair.ancestor) }
}

# The directory name of a repository, or null.
def repo-name [repo: any]: nothing -> any {
  if $repo == null { null } else { $repo.root | path basename }
}

# A written path with its existing directory resolved, so a symlinked parent names the directory the
# write lands in.
def physical [path: string]: nothing -> string {
  let dir = ($path | path dirname)
  if ($dir | path exists) { $dir | path expand | path join ($path | path basename) } else { $path }
}

# The repository containing a written path, or null.
def repo-of-file [repos: record, path: string]: nothing -> any {
  $repos | get -o ($path | path dirname)
}

# Paths git ignores, checked once per checkout. A path whose directory is gone is kept, since a
# checkout ignores its nested worktrees and would otherwise drop them.
def ignored-paths [repos: record, paths: list<string>]: nothing -> list<string> {
  $paths
  | where {|path| $path | path dirname | path exists }
  | each {|path| {path: $path, repo: (repo-of-file $repos $path)} }
  | where repo != null
  | group-by {|row| $row.repo.checkout }
  | transpose checkout rows
  | each {|group|
    let run = (
      $group.rows | get path | str join (char nul)
      | ^git -C $group.checkout check-ignore -z --stdin
      | complete
    )
    if $run.exit_code not-in [0 1] {
      error make {msg: $"git check-ignore failed in ($group.checkout): ($run.stderr | str trim)"}
    }
    $run.stdout | split row (char nul) | compact --empty
  }
  | flatten
}

# Split a list of files among their repositories by distinct-file count, largest share first.
def shares [repos: record, ignored: list<string>]: list<string> -> record {
  let repos_of_files = (
    $in
    | uniq
    | where {|path| $path not-in $ignored }
    | each {|path| repo-name (repo-of-file $repos $path) }
    | compact
    | sort
  )
  let counts = ($repos_of_files | uniq --count)
  if ($counts | is-empty) {
    return {}
  }
  let total = ($counts | get count | math sum)
  $counts
  | each {|count| {repo: $count.value, share: ($count.count / $total | math round --precision 2)} }
  | sort-by share --reverse
  | reduce --fold {} {|count, acc| $acc | insert $count.repo $count.share }
}

# --------------------------------------------------------------------------------------------------
# Units
# --------------------------------------------------------------------------------------------------

# The depth of a session's parent chain, zero when no loaded session delegated to it.
def depth [parents: record, transcript: string, seen: list = []]: nothing -> int {
  let parent = ($parents | get -o $transcript)
  if $parent == null or ($seen | any {|path| $path == $transcript }) {
    0
  } else {
    1 + (depth $parents $parent ($seen | append $transcript))
  }
}

# Give every turn the unit of the prompt whose turn started it, or of the run it belongs to. A
# delegate's turn follows the parent turn that was running, so parallel delegates join one prompt.
def link []: list -> list {
  let sessions = $in
  let transcripts = ($sessions | get transcript)
  let parents = (
    $sessions
    | where {|s| $s.parent != null and $s.parent in $transcripts }
    | reduce --fold {} {|s, acc| $acc | insert $s.transcript $s.parent }
  )
  let ordered = ($sessions | sort-by {|s| depth $parents $s.transcript })
  let units = (
    $ordered
    | reduce --fold {} {|s, acc|
      let parent = (if $s.parent == null { [] } else { $acc | get -o $s.parent | default [] })
      let prompts = (if $s.attended { $s.turns | where kind == "prompt" } else { [] })
      let turns = (
        $s.turns
        | each {|t|
          let own = ($prompts | where ts <= $t.ts | last)
          let anchor = (
            if $own != null or ($parent | is-empty) {
              null
            } else {
              $parent | where ts <= $t.ts | last
            }
          )
          let unit = (
            if $own != null {
              $"($s.transcript)#($own.ts | into int)"
            } else if $anchor != null {
              $anchor.unit
            } else {
              $s.transcript
            }
          )
          $t | insert unit $unit
        }
      )
      $acc | insert $s.transcript $turns
    }
  )
  $sessions | each {|s| $s | update turns ($units | get -o $s.transcript) }
}

# Each prompt with earned human hours and same-day unit agent time, rounded to 0.0001.
def credit-prompts [cfg: record, units: record]: list -> list<record> {
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
      ($p.item.end + $cfg.readingMinutes * 1min)
      ($p.item.ts + $cfg.maxMinutes * 1min)
      ($timeline | get -o ($p.index + 1) | get -o ts)
    ]
    let hours = ((($until | compact | math min) - $p.item.ts) / 1hr)
    let day = ($p.item.ts | format date "%Y-%m-%d" | into datetime)
    let agent = (
      ($units | get $p.item.unit)
      | where ts >= $day and ts < ($day + 1day)
      | agent-hours $cfg
    )
    $p.item | insert hours ($hours | math round --precision 4) | insert agent $agent
  }
}

# Each prompt's unit turns that started after the prompt's day, one entry per later day: the
# origin's date, time, and text, that day's agent time, and the repository shares of the files it
# wrote, or the prompt's shares when it wrote none.
def continuations [
  cfg: record
  units: record
  repos: record
  ignored: list<string>
  excerpt_chars: int
]: list -> list<record> {
  $in
  | each {|p|
    let since = ($p.ts | format date "%Y-%m-%d" | into datetime)
    $units
    | get $p.unit
    | where ts >= ($since + 1day)
    | group-by {|t| $t.ts | format date "%Y-%m-%d"}
    | values
    | each {|turns|
      let wrote = ($turns | get -o paths | flatten | shares $repos $ignored)
      {
        transcript: $p.transcript
        ts: ($turns.0.ts | format date "%Y-%m-%d" | into datetime)
        from: ($p.ts | format date "%Y-%m-%d %H:%M")
        text: ($p.text | excerpt $excerpt_chars)
        agent: ($turns | agent-hours $cfg)
        repos: (if ($wrote | is-empty) { $p.repos } else { $wrote })
      }
    }
  }
  | flatten
}

# Each unit's repository shares, from the distinct files it and its delegates wrote.
def unit-shares [repos: record, ignored: list<string>]: record -> record {
  $in
  | transpose unit turns
  | reduce --fold {} {|unit, acc|
    let paths = ($unit.turns | get -o paths | flatten)
    $acc | insert $unit.unit ($paths | shares $repos $ignored)
  }
}

# Time the turns spent, each capped and cut at its `idle` record, the last one before a long gap
# or the next turn's start. Every turn adds, so a parallel delegate spends its own time.
def agent-hours [cfg: record]: list<record> -> float {
  let spent = (
    $in
    | reduce --fold 0sec {|t, acc|
      $acc + (([$t.end ($t.ts + $cfg.agentMaxMinutes * 1min) $t.idle] | compact | math min) - $t.ts)
    }
  )
  ($spent / 1hr) | math round --precision 4
}

# --------------------------------------------------------------------------------------------------
# Days
# --------------------------------------------------------------------------------------------------

def stamp [excerpt_chars: int]: record -> record {
  let event = $in
  {
    at: ($event.ts | format date "%H:%M")
    text: ($event.text | excerpt $excerpt_chars)
  }
}

# A turn's final reply is the last one before the next prompt.
def final-replies []: list -> list {
  let events = ($in | where kind in [prompt reply])
  $events
  | enumerate
  | where {|e|
    $e.item.kind == "reply" and ($events | get -o ($e.index + 1) | get -o kind) != "reply"
  }
  | get item
}

# A run is agent work no prompt started: a worker, a headless run, or a session before its first
# prompt. Each day lists the runs with turns started that day and their agent time that day.
def agent-run [
  cfg: record
  start: datetime
  session: record
  turns: list
  repos: record
  ignored: list<string>
  excerpt_chars: int
]: nothing -> any {
  let end = ($start + 1day)
  let today = ($turns | where ts >= $start and ts < $end)
  if ($today | is-empty) {
    null
  } else {
    let paths = ($today | get -o paths | flatten)
    let text = ($today | each {|t| $t.text } | where {|t| $t != "" } | get -o 0 | default "")
    {
      tool: $session.tool
      session: $session.id
      cwd: $session.cwd
      repo: $session.repo
      at: ($today.0.ts | format date "%H:%M")
      agent: ($today | agent-hours $cfg)
      repos: ($paths | shares $repos $ignored)
      text: ($text | excerpt $excerpt_chars)
    }
  }
}

def day [
  cfg: record
  start: datetime
  sessions: list
  credited: list
  units: record
  prompt_units: list<string>
  continuations: list
  repos: record
  ignored: list<string>
  excerpt_chars: int
]: nothing -> record {
  let end = ($start + 1day)
  let today = ($credited | where ts >= $start and ts < $end)
  let later = ($continuations | where ts >= $start and ts < $end)
  let runs = (
    $units
    | transpose unit turns
    | where {|unit| $unit.unit not-in $prompt_units }
    | each {|unit|
      let session = ($sessions | where transcript == $unit.unit | first)
      agent-run $cfg $start $session $unit.turns $repos $ignored $excerpt_chars
    }
    | compact
    | sort-by at
  )
  {
    date: ($start | format date "%Y-%m-%d")
    weekday: ($start | format date "%a")
    sessions: (
      (($today | get transcript) ++ ($later | get transcript))
      | uniq
      | each {|transcript|
        let s = ($sessions | where transcript == $transcript | first)
        let prompts = ($today | where transcript == $transcript)
        let events = (
          if ($prompts | is-empty) {
            []
          } else {
            # Turns started today keep their replies past midnight, until the next prompt.
            let first = ($prompts | first | get ts)
            let next = ($s.turns | where kind == "prompt" and ts >= $end | get -o 0.ts)
            $s.events | where {|e| $e.ts >= $first and ($next == null or $e.ts < $next) }
          }
        )
        {
          tool: $s.tool
          session: $s.id
          cwd: $s.cwd
          repo: $s.repo
          prompts: (
            $prompts
            | each {|p|
              {
                at: ($p.ts | format date "%H:%M")
                hours: $p.hours
                agent: $p.agent
                repos: $p.repos
                text: ($p.text | excerpt $excerpt_chars)
              }
            }
          )
          replies: ($events | final-replies | each { stamp $excerpt_chars } | where text != "")
          continued: (
            $later
            | where transcript == $transcript
            | select from text agent repos
          )
        }
      }
    )
    runs: $runs
  }
}

# Every repository named in the output, mapped to its root. A repeated directory name keeps the
# first root found.
def repositories [repos: record, names: list<string>]: nothing -> record {
  let found = ($repos | values | compact | uniq-by root)
  $names
  | reduce --fold {} {|name, acc|
    let root = ($found | where {|repo| ($repo.root | path basename) == $name } | get -o 0.root)
    if $root == null { $acc } else { $acc | insert $name $root }
  }
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Print the agent sessions on this host for a range of local dates as JSON.
#
# Each day lists its sessions, with their `prompts`, `replies`, and `continued`, and its `runs`. A
# session's `prompts` are the prompts a person typed or answered, each with its `hours`, `agent`,
# and `repos`. A session's `repo` is the repository holding its `cwd`.
#
# A prompt's `hours` is the human credit it earned: the time until its turn ends plus a reading
# allowance, cut short by the next prompt in any session and capped per prompt, excluding
# parallel overlap and turns the user did not start. Its `agent` is the time its turn and every
# delegate it started, such as a subagent, teammate, Codex subagent thread, or OMP advisor, spent:
# each turn from its start to its first reply or last model output, counting that turn on the day
# it started and adding each transcript's time. Its `repos` gives each repository's share of the
# files its turns and delegates wrote, and is empty when they wrote none.
#
# A session's `replies` hold, per turn, the last answer before the next prompt, including one
# after midnight. Its `continued` lists each prompt from an earlier day whose turns started that
# day, with `from` (the prompt's date and time), `text` (its excerpt), and those turns' `agent`
# and `repos`, falling back to the prompt's `repos` when they wrote nothing. A day's `runs` list
# agent work no prompt started, such as Workmux workers and headless runs.
#
# The top-level `labels` gives each repository's labels and the default for unlisted ones, and
# `repositories` gives each repository's root.
def main [
  from: string # First local date, as YYYY-MM-DD
  to?: string # Last local date, as YYYY-MM-DD, the first date by default
  --config: path # Wrapper-supplied JSON with the host's labels, policy, and source directories
  --excerpt-chars: int = 400 # Characters kept per prompt and reply, or 0 to keep the text whole
]: nothing -> nothing {
  if $config == null {
    error make {msg: "--config <path> is required"}
  }
  let cfg = (open $config)
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
  let linked = ($sessions | link)
  let turns = (
    $linked
    | each {|s| $s.turns | insert transcript $s.transcript }
    | flatten
  )
  let paths = ($turns | get -o paths | flatten | uniq)
  let dirs = (($paths | each {|path| $path | path dirname }) ++ ($linked | get cwd) | uniq)
  let repos = (repository-map $dirs)
  let ignored = (ignored-paths $repos $paths)
  let linked = ($linked | each {|s| $s | insert repo (repo-name ($repos | get -o $s.cwd)) })
  let units = ($turns | group-by unit)
  let shares = ($units | unit-shares $repos $ignored)
  let credited = (
    $linked
    | credit-prompts $cfg $units
    | each {|p| $p | insert repos ($shares | get $p.unit) }
  )
  let continuations = ($credited | continuations $cfg $units $repos $ignored $excerpt_chars)
  let prompt_units = ($credited | get unit | uniq)
  let days = (
    $days
    | each {|start|
      (
        day $cfg $start $linked $credited $units $prompt_units $continuations $repos $ignored
          $excerpt_chars
      )
    }
  )
  let names = (
    (
      ($days | each {|day| $day.sessions | each {|s| $s.repo } })
      ++ ($days | each {|day| $day.sessions | each {|s| $s.prompts | get repos | columns } })
      ++ ($days | each {|day| $day.sessions | each {|s| $s.continued | get repos | columns } })
      ++ ($days | each {|day| $day.runs | each {|r| $r.repo } })
      ++ ($days | each {|day| $day.runs | each {|r| $r.repos | columns } })
    )
    | flatten
    | flatten
    | flatten
    | compact
    | uniq
  )
  {
    labels: $cfg.labels
    repositories: (repositories $repos $names)
    days: $days
  }
  | to json
  | print
}
