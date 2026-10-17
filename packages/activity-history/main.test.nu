#!/usr/bin/env nu

# ==================================================================================================
# Activity History Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join main.nu)
const CLAUDE_STUB = ($SCRIPT_DIR | path join claude.stub.nu)

const WEEKDAY = "2026-10-15"
const SATURDAY = "2026-10-17"

def scratch []: nothing -> record {
  let dir = (mktemp --directory)
  {dir: $dir, root: ($dir | path join tree)}
}

def claude-stub [t: record]: nothing -> string {
  let stub = ($t.dir | path join claude)
  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $CLAUDE_STUB) | save $stub
  ^chmod +x $stub
  $stub
}

def config [t: record, overrides: record]: nothing -> string {
  let path = ($t.dir | path join config.json)

  {
    host: test
    root: $t.root
    userConfig: ($t.dir | path join local.toml)
    fallback: work
    rules: [{match: "**/nixos-config*", context: personal}]
    ignore: []
    sources: [claude]
    gitRoots: [/work]
    claude: "false"
    window: {start: "10hr", end: "20hr"}
    lunch: {start: "12hr", end: "13hr"}
  }
  | merge $overrides
  | to json
  | save --force $path
  $path
}

# Run a subcommand in UTC, so the fixtures' `Z` timestamps read as local times.
def run [cfg: string, ...args: string, --extra-env: record = {}]: nothing -> record {
  with-env ({TZ: UTC, ACTIVITY_HISTORY_CONFIG: $cfg} | merge $extra_env) {
    ^$nu.current-exe --no-config-file $SCRIPT ...$args | complete
  }
}

def measure [t: record, date: string, overrides: record = {}]: nothing -> record {
  let run = (run (config $t $overrides) measure $date)
  assert equal $run.exit_code 0 $run.stderr

  $run.stdout | from json
}

# Build a session's prompt and final reply at `HH:MM` times on `date`.
def turn [
  session: string
  cwd: string
  date: string
  prompt: string
  reply: string
]: nothing -> list {
  let at = {|clock: string| $"($date)T($clock):00.000Z" }
  let base = {source: claude, session: $session, cwd: $cwd, mode: interactive, title: $session}
  [
    ($base | merge {kind: prompt, ts: (do $at $prompt), text: "do it"})
    ($base | merge {kind: reply, ts: (do $at $reply), text: "done"})
  ]
}

def events-file [t: record, date: string, source: string]: nothing -> string {
  $t.root | path join events ($date | str substring 0..3) $date $"($source).jsonl"
}

def write-events [t: record, date: string, events: list]: nothing -> nothing {
  let path = (events-file $t $date claude)
  mkdir ($path | path dirname)
  $events | each { to json --raw } | str join "\n" | save --force $path
}

def spans [metrics: record]: nothing -> list {
  $metrics.intervals | each {|i| $"($i.start)-($i.end) ($i.minutes)" }
}

def "test turns join across short gaps and short turns take five minutes" [] {
  let t = (scratch)
  write-events $t $WEEKDAY (
    (turn a /work/app $WEEKDAY "10:00" "10:20")
    ++ (turn a /work/app $WEEKDAY "10:30" "10:50")
    ++ (turn a /work/app $WEEKDAY "15:00" "15:01")
  )

  let metrics = (measure $t $WEEKDAY)

  assert equal (spans $metrics) ["10:00-10:50 50.0" "15:00-15:05 5.0"]
}

def "test minutes split across the window, lunch, and after hours" [] {
  let t = (scratch)
  write-events $t $WEEKDAY (
    (turn a /work/app $WEEKDAY "11:30" "13:30") ++ (turn b /work/app $WEEKDAY "19:50" "20:20")
  )

  let metrics = (measure $t $WEEKDAY)

  assert equal ($metrics.intervals | get hours) [
    {in: 60.0, lunch: 60.0, after: 0.0}
    {in: 10.0, lunch: 0.0, after: 20.0}
  ]
  assert equal ($metrics.totals | select work_in_hours work_lunch work_after_hours) {
    work_in_hours: 70.0
    work_lunch: 60.0
    work_after_hours: 20.0
  }
}

def "test parallel sessions keep their full minutes" [] {
  let t = (scratch)
  write-events $t $WEEKDAY (
    (turn a /work/app $WEEKDAY "14:00" "15:00") ++ (turn b /work/lib $WEEKDAY "14:30" "15:00")
  )

  let totals = (measure $t $WEEKDAY | get totals)

  assert equal $totals.sum 90.0
  assert equal $totals.wall_clock_in_window 60.0
  assert equal $totals.unattributed 480.0
}

def "test local rules win over defaults and weekends are personal" [] {
  let t = (scratch)
  let dirs = [/work/app /home/me/nixos-config/.claude/worktrees/x /work/side]
  let events = (
    $dirs | enumerate | each {|c| turn $"s($c.index)" $c.item $WEEKDAY "14:00" "14:10" }
  )
  write-events $t $WEEKDAY ($events | flatten)
  write-events $t $SATURDAY (turn a /work/app $SATURDAY "14:00" "14:10")
  '
    [[rules]]
    match = "/work/side"
    context = "personal"
    ' | str dedent | save ($t.dir | path join local.toml)
  let defaults = {
    fallback: personal
    rules: [{match: /work, context: work} {match: "**/nixos-config*", context: personal}]
  }

  let weekday = (measure $t $WEEKDAY $defaults)
  let saturday = (measure $t $SATURDAY $defaults)

  assert equal ($weekday.intervals | select project context) [
    {project: app, context: work}
    {project: nixos-config, context: personal}
    {project: side, context: personal}
  ]
  assert equal ($saturday.intervals | get context) [personal]
  assert equal $saturday.totals.unattributed 0.0
}

def "test ignored paths drop their sessions" [] {
  let t = (scratch)
  write-events $t $WEEKDAY (
    (turn a /tmp/probe $WEEKDAY "14:00" "14:10") ++ (turn b /work/app $WEEKDAY "14:00" "14:10")
  )
  'ignore = ["/tmp"]' | save ($t.dir | path join local.toml)

  let metrics = (measure $t $WEEKDAY)

  assert equal ($metrics.intervals | get project) [app]
}

def "test a failing source keeps its previous events" [] {
  let t = (scratch)
  let events = (events-file $t $WEEKDAY calendar)
  let meeting = '{"source":"calendar","kind":"meeting","title":"Sync"}'
  mkdir ($events | path dirname)
  $meeting | save $events
  let cfg = (config $t {sources: [calendar]})

  let run = (run $cfg collect $WEEKDAY --extra-env {PATH: []})
  assert equal $run.exit_code 0 $run.stderr

  assert equal (open --raw $events) $meeting
  assert str contains $run.stderr "2026-10-15: calendar failed"
}

def "test claude prompts injected by the harness are not human turns" [] {
  let t = (scratch)
  let session = ($t.dir | path join home .claude projects app s.jsonl)
  mkdir ($session | path dirname)
  let user = {type: user, cwd: /work/app, timestamp: $"($WEEKDAY)T14:00:00.000Z"}
  [
    ($user | merge {message: {content: "fix the parser"}})
    ($user | merge {message: {content: "Another Claude session sent a message: hi"}})
    ($user | merge {message: {content: "<command-name>/review</command-name>"}})
  ]
  | each { to json --raw }
  | str join "\n"
  | save $session
  let cfg = (config $t {})

  let run = (run $cfg collect $WEEKDAY --extra-env {HOME: ($t.dir | path join home)})
  assert equal $run.exit_code 0 $run.stderr

  let events = (open --raw (events-file $t $WEEKDAY claude) | from json --objects)
  assert equal ($events | get text) ["fix the parser"]
}

def "test omp tool steps end turns without becoming replies" [] {
  let t = (scratch)
  let session = ($t.dir | path join home .omp agent sessions app s.jsonl)
  mkdir ($session | path dirname)
  let at = {|clock: string| $"($WEEKDAY)T($clock):00.000Z" }
  let message = {|clock: string, role: string, extra: record|
    let body = ({role: $role, content: "text"} | merge $extra)
    {type: message, timestamp: (do $at $clock), message: $body}
  }
  [
    {type: session, cwd: /work/app}
    (do $message "14:00" user {attribution: user})
    (do $message "14:05" assistant {stopReason: toolUse})
    (do $message "14:20" assistant {stopReason: stop})
  ]
  | each { to json --raw }
  | str join "\n"
  | save $session
  let cfg = (config $t {sources: [omp]})

  let run = (run $cfg collect $WEEKDAY --extra-env {HOME: ($t.dir | path join home)})
  assert equal $run.exit_code 0 $run.stderr

  let events = (open --raw (events-file $t $WEEKDAY omp) | from json --objects)
  assert equal ($events | get kind) [prompt end reply]
}

def "test runs retry recent days that failed to collect a source" [] {
  let t = (scratch)
  let today = (date now | format date "%Y-%m-%d" | into datetime)
  let days = (2..4 | each {|n| $today - ($n * 1day) | format date "%Y-%m-%d" })
  $days | enumerate | each {|d|
    let base = ($t.root | path join days ($d.item | str substring 0..3) $d.item)
    mkdir ($base | path dirname)
    "" | save $"($base).md"
    let failed = if $d.index == 1 { [calendar] } else { [] }
    {failed_sources: $failed} | to json | save $"($base).metrics.json"
  }
  let cfg = (config $t {sources: [], claude: (claude-stub $t)})
  let author = {name: test, email: test@example.com}
  let identity = {
    GIT_AUTHOR_NAME: $author.name
    GIT_AUTHOR_EMAIL: $author.email
    GIT_COMMITTER_NAME: $author.name
    GIT_COMMITTER_EMAIL: $author.email
  }

  let run = (run $cfg run --extra-env $identity)
  assert equal $run.exit_code 0 $run.stderr

  let message = (^git -C $t.root log -1 --format=%s)
  assert str contains $message ($days | get 1)
  assert not ($message | str contains ($days | get 0))
  assert not ($message | str contains ($days | get 2))
}
