#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join activity-digest.nu)

const DAY = "2026-10-15"
const HUMAN = {origin: {kind: human}}

# A clock time on the reported day, or a full date and time.
def at [clock: string]: nothing -> string {
  if ($clock | str contains T) { $"($clock):00.000Z" } else { $"($DAY)T($clock):00.000Z" }
}

def transcript [dir: string, path: list<string>, records: list]: nothing -> nothing {
  let file = ($dir | path join ...$path)
  mkdir ($file | path dirname)
  $records | each { to json --raw } | str join "\n" | save $file
}

def claude-user [cwd: string, clock: string, text: string, extra: record = {}]: nothing -> record {
  {type: user, cwd: $cwd, timestamp: (at $clock), message: {role: user, content: $text}}
  | merge $extra
}

def claude-prompt [cwd: string, clock: string, text: string]: nothing -> record {
  claude-user $cwd $clock $text $HUMAN
}

def claude-queued [
  cwd: string
  clock: string
  text: string
  kind: string = "human"
]: nothing -> record {
  let attachment = {type: queued_command, origin: {kind: $kind}, prompt: $text}
  {type: attachment, cwd: $cwd, timestamp: (at $clock), attachment: $attachment}
}

def claude-notification [cwd: string, clock: string]: nothing -> record {
  claude-user $cwd $clock "<task-notification>" {origin: {kind: task-notification}}
}

def claude-reply [cwd: string, clock: string, text: string = "done"]: nothing -> record {
  let message = {stop_reason: end_turn, content: [{type: text, text: $text}]}
  {type: assistant, cwd: $cwd, timestamp: (at $clock), message: $message}
}

def codex-transcript [dir: string, meta: record, records: list<record>]: nothing -> nothing {
  let path = [codex sessions ...($DAY | split row -) $"($meta.id).jsonl"]
  transcript $dir $path ([{type: session_meta, payload: $meta}] ++ $records)
}

def codex-event [clock: string, payload: record]: nothing -> record {
  {type: event_msg, timestamp: (at $clock), payload: $payload}
}

# A turn's task start, followed by its prompt if it has `text` and its completion at a `done` time.
def codex-turn [clock: string, text?: string, --done: string]: nothing -> list<record> {
  let item = {type: UserMessage, content: [{type: text, text: $text}]}
  [
    (codex-event $clock {type: task_started})
    (if $text != null { codex-event $clock {type: item_completed, item: $item} })
    (if $done != null { codex-event $done {type: task_complete, last_agent_message: ok} })
  ]
  | compact
}

def omp-user [clock: string, text: string, --agent]: nothing -> record {
  let attribution = if $agent { "agent" } else { "user" }
  let message = {role: user, attribution: $attribution, content: $text}
  {type: message, timestamp: (at $clock), message: $message}
}

def omp-reply [clock: string, text: string = "done"]: nothing -> record {
  let message = {role: assistant, stopReason: stop, content: $text}
  {type: message, timestamp: (at $clock), message: $message}
}

def digest-run [
  dir: string
  overrides: record = {}
  --excerpt-chars: int = 400
]: nothing -> record {
  let config_file = ($dir | path join config.json)
  {
    context: personal
    excludedDirs: ['/\.claude/worktrees/workmux/']
    worktreePatterns: ['/\.claude/worktrees/[^/]+.*$']
    personalProjects: [nixos-config]
    readingMinutes: 10
    maxMinutes: 60
    agentMaxMinutes: 120
    assistantDirs: {
      claude: ($dir | path join claude)
      codex: ($dir | path join codex)
      omp: ($dir | path join omp)
    }
  }
  | merge $overrides
  | to json
  | save --force $config_file

  let args = [$config_file $DAY $"--excerpt-chars=($excerpt_chars)"]
  with-env {TZ: UTC} { ^$nu.current-exe --no-config-file $SCRIPT ...$args | complete }
}

def digest-output [
  dir: string
  overrides: record = {}
  --excerpt-chars: int = 400
]: nothing -> record {
  let run = (digest-run $dir $overrides --excerpt-chars=$excerpt_chars)
  assert equal $run.exit_code 0 $run.stderr

  $run.stdout | from json
}

# Run the digest in UTC, so the fixtures' `Z` timestamps read as local times.
def digest-day [
  dir: string
  overrides: record = {}
  --excerpt-chars: int = 400
]: nothing -> record {
  digest-output $dir $overrides --excerpt-chars=$excerpt_chars | get days.0
}

def "test only prompts a person typed count" [] {
  let dir = (mktemp --directory)
  let app = "/work/app"
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $app "10:00" "fix the parser")
    (claude-user $app "11:00" "peer message" {origin: {kind: peer}, isMeta: true})
    (claude-user $app "12:00" "From the lead: continue" {teamName: t})
    (claude-user $app "13:00" "<command-name>/export</command-name>")
    (claude-user $app "13:30" "/compact")
    (claude-queued $app "13:45" "<task-notification>" task-notification)
    (claude-prompt $app "14:00" "/review")
  ]
  codex-transcript $dir {id: user, cwd: $app, thread_source: user} (codex-turn "16:00" "check CI")
  codex-transcript $dir {id: import, cwd: $app} (codex-turn "17:00" "imported")
  transcript $dir [omp sessions app a.jsonl] [
    {type: session, id: omp, cwd: $app}
    (omp-user "18:00" "plan it")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions | each {|s| {tool: $s.tool, prompts: ($s.prompts | get at)} }) [
    {tool: claude, prompts: ["10:00" "14:00"]}
    {tool: codex, prompts: ["16:00"]}
    {tool: omp, prompts: ["18:00"]}
  ]
}

def "test sessions without a person add only agent time" [] {
  let dir = (mktemp --directory)
  let handback = {stop_reason: tool_use, content: [{type: tool_use, name: SubagentHandback}]}
  transcript $dir [claude projects app teammate.jsonl] [
    (claude-user /work/app "10:00" "From the lead: continue" {teamName: t})
    (claude-reply /work/app "10:30")
  ]
  transcript $dir [claude projects app lead subagents agent-a.jsonl] [
    (claude-user /work/app/.claude/worktrees/agent-a "11:00" "Review it" (
      $HUMAN | insert isSidechain true
    ))
    {type: assistant, timestamp: (at "11:30"), message: $handback}
  ]
  transcript $dir [claude projects lib headless.jsonl] [
    (claude-user /work/lib "13:00" "Reply with exactly: OK" {entrypoint: sdk-cli})
    (claude-reply /work/lib "13:15")
  ]
  codex-transcript $dir {id: exec, cwd: /work/cli, thread_source: user, source: exec} (
    codex-turn "14:00" "probe" --done "14:30"
  )
  codex-transcript $dir {id: sub, cwd: /work/cli, thread_source: subagent} (
    codex-turn "15:00" "review the diff" --done "15:30"
  )

  let day = (digest-day $dir)

  assert equal $day.sessions []
  assert equal $day.hours {
    human: {total: 0.0, projects: {}}
    agent: {total: 2.25, projects: {app: 1.0, lib: 0.25, cli: 1.0}}
  }
}

def "test nested OMP advisors extend agent hours without human excerpts" [] {
  let dir = (mktemp --directory)
  transcript $dir [omp sessions app parent.jsonl] [
    {type: session, id: parent, cwd: /work/app}
    (omp-user "10:00" "review it")
    (omp-reply "10:30")
  ]
  transcript $dir [omp sessions app parent __advisor.jsonl] [
    {type: session, id: advisor, cwd: /work/app}
    (omp-user "10:15" "check the API" --agent)
    (omp-reply "11:00")
  ]

  let day = (digest-day $dir)

  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 1.0, projects: {app: 1.0}}
  }
  assert equal ($day.sessions | get session) [parent]
  assert equal $day.sessions.0.replies [{at: "10:30", text: done}]
}

def "test worktrees count for their repository but Workmux workers earn only agent time" [] {
  let dir = (mktemp --directory)
  let worktree = "/work/app/.claude/worktrees/fix"
  let worker = "/work/app/.claude/worktrees/workmux/fix"
  transcript $dir [claude projects worktree a.jsonl] [
    (claude-prompt $worktree "10:00" "fix it")
    (claude-reply $worktree "10:30")
  ]
  transcript $dir [claude projects worker b.jsonl] [
    (claude-prompt $worker "11:00" "# Task: fix it")
    (claude-reply $worker "11:30")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions | select cwd project) [{cwd: $worktree, project: app}]
  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 1.0, projects: {app: 1.0}}
  }
}

def "test sessions report project, context, and transcript, and personal projects are listed" [] {
  let dir = (mktemp --directory)
  let root = ($dir | path join claude projects)
  transcript $dir [claude projects app a.jsonl] [(claude-prompt /work/app "10:00" "ship")]
  transcript $dir [claude projects cfg b.jsonl] [(claude-prompt /work/nixos-config "11:00" "tidy")]
  transcript $dir [claude projects notes c.jsonl] [(claude-prompt /work/notes "12:00" "file")]

  let output = (digest-output $dir {context: work, personalProjects: [nixos-config notes]})
  let day = $output.days.0

  assert equal $output.personalProjects [nixos-config notes]
  assert equal ($day.sessions | select project context transcript) [
    {project: app, context: work, transcript: ($root | path join app a.jsonl)}
    {project: nixos-config, context: personal, transcript: ($root | path join cfg b.jsonl)}
    {project: notes, context: personal, transcript: ($root | path join notes c.jsonl)}
  ]
}

def "test a prompt earns its turn and a reading allowance until the next prompt anywhere" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "release it, I'll watch")
    (claude-reply /work/app "11:30")
    (claude-prompt /work/app "12:00" "fix the test")
    (claude-reply /work/app "12:06")
    (claude-prompt /work/app "13:00" "refactor the parser")
    (claude-reply /work/app "13:45")
    (claude-prompt /work/app "14:00" "merge it")
    (claude-reply /work/app "14:06")
    (claude-notification /work/app "14:30")
    (claude-reply /work/app "14:50")
  ]
  transcript $dir [claude projects lib b.jsonl] [
    (claude-prompt /work/lib "13:24" "review the API")
  ]

  let day = (digest-day $dir {readingMinutes: 12})

  assert equal $day.hours.human {total: 2.2, projects: {app: 2.0, lib: 0.2}}
  assert equal ($day.sessions | each { get prompts.hours }) [[1.0 0.3 0.4 0.3] [0.2]]
}

def "test steering prompts and triggers share the first reply" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "start")
    (claude-queued /work/app "10:05" "also check tests")
    (claude-notification /work/app "10:08")
    (claude-reply /work/app "10:30")
  ]

  let day = (digest-day $dir)

  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 0.5, projects: {app: 0.5}}
  }
  assert equal $day.sessions.0.replies [{at: "10:30", text: done}]
  assert equal ($day.sessions.0.prompts | select at text) [
    {at: "10:00", text: start}
    {at: "10:05", text: "also check tests"}
  ]
  assert equal ($day.sessions.0.prompts | get hours) [0.0833 0.5833]
}

def "test parallel agents on a project count once" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "build it")
    (claude-reply /work/app "11:00")
  ]
  transcript $dir [omp sessions app b.jsonl] [
    {type: session, id: omp, cwd: /work/app}
    (omp-user "10:30" "build the API" --agent)
    (omp-reply "11:30" "built")
  ]
  transcript $dir [claude projects lib c.jsonl] [
    (claude-notification /work/lib "10:00")
    (claude-reply /work/lib "10:30")
  ]

  let day = (digest-day $dir)

  assert equal $day.hours.agent {total: 2.0, projects: {app: 1.5, lib: 0.5}}
}

def "test a turn without a reply earns no agent time" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    (claude-reply /work/app "10:30")
    (claude-notification /work/app "11:00")
  ]

  let day = (digest-day $dir)

  assert equal $day.hours.agent {total: 0.5, projects: {app: 0.5}}
}

def "test an agent turn earns at most the cap" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    (claude-reply /work/app "13:00")
  ]

  let day = (digest-day $dir {agentMaxMinutes: 90})

  assert equal $day.hours.agent {total: 1.5, projects: {app: 1.5}}
}

def "test agent turns across midnight count only within the day" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "2026-10-14T23:30")
    (claude-reply /work/app "00:30")
    (claude-notification /work/app "23:00")
    (claude-reply /work/app "2026-10-16T01:00")
  ]

  let day = (digest-day $dir)

  assert equal $day.hours.agent {total: 1.5, projects: {app: 1.5}}
}

def "test canceled Codex turns cannot borrow a later reply" [] {
  let dir = (mktemp --directory)
  let prompt = {type: UserMessage, content: [{type: text, text: "start"}]}
  codex-transcript $dir {id: canceled, cwd: /work/app, thread_source: user} [
    (codex-event "10:00" {type: task_started, turn_id: first})
    (codex-event "10:00" {type: item_completed, item: $prompt})
    (codex-event "10:01" {type: turn_aborted, turn_id: first})
    (codex-event "13:00" {type: task_started, turn_id: second})
    (codex-event "13:10" {type: task_complete, last_agent_message: done})
    (codex-event "13:11" {type: turn_aborted, turn_id: second})
    (codex-event "13:12" {type: task_complete, last_agent_message: final})
  ]

  let day = (digest-day $dir)

  assert equal $day.hours {
    human: {total: 0.17, projects: {app: 0.17}}
    agent: {total: 0.17, projects: {app: 0.17}}
  }
  assert equal $day.sessions.0.replies [{at: "13:12", text: final}]
}

def "test a day keeps its final replies past midnight until the next prompt" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "start")
    (claude-reply /work/app "10:05" "working")
    (claude-notification /work/app "10:08")
    (claude-reply /work/app "10:12" "started")
    (claude-prompt /work/app "10:15" "ship it")
    (claude-reply /work/app "2026-10-16T00:30" "merged")
    (claude-prompt /work/app "2026-10-16T09:00" "next")
    (claude-reply /work/app "2026-10-16T09:05" "tomorrow")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions.0.replies | select at text) [
    {at: "10:12", text: started}
    {at: "00:30", text: merged}
  ]
}

def "test a prompt is cut by a prompt from another session after midnight" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "2026-10-15T23:30" "late")
    (claude-reply /work/app "2026-10-16T00:20")
  ]
  transcript $dir [claude projects lib b.jsonl] [
    (claude-prompt /work/lib "2026-10-16T00:05" "early")
    (claude-reply /work/lib "2026-10-16T00:10")
  ]

  let day = (digest-day $dir)

  assert equal $day.hours.human {total: 0.58, projects: {app: 0.58}}
  assert equal ($day.sessions | each { get prompts | get hours }) [[0.5833]]
}

def "test the excerpt length keeps whole text at zero and cuts at a custom limit" [] {
  let dir = (mktemp --directory)
  let long = (
    $"
    first
    ("" | fill --character a --width 450)
    "
    | str dedent
  )
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" $long)
    (claude-reply /work/app "10:30" $long)
  ]

  let excerpted = (digest-day $dir)
  let short = (digest-day $dir --excerpt-chars 10)
  let full = (digest-day $dir --excerpt-chars 0)

  let excerpt = $"first ("" | fill --character a --width 394)..."
  let short_excerpt = "first aaaa..."
  let projected = {|day|
    $day.sessions | each {|s| {prompt: $s.prompts.0.text, reply: $s.replies.0.text} }
  }
  assert equal (do $projected $excerpted) [{prompt: $excerpt, reply: $excerpt}]
  assert equal (do $projected $short) [{prompt: $short_excerpt, reply: $short_excerpt}]
  assert equal (do $projected $full) [{prompt: $long, reply: $long}]
}

def "test Codex request headings are stripped from prompts" [] {
  let dir = (mktemp --directory)
  let cases = [
    {
      name: "Desktop browser context"
      clock: "11:00"
      done: "11:30"
      input: (
        "
        <in-app-browser-context source="ambient-ui-state">
        page text
        ## My request:
        quoted earlier transcript
        </in-app-browser-context>
        ## My request:
        summarize it
        "
        | str dedent
      )
      expected: "summarize it"
    }
    {
      name: "Desktop IDE context"
      clock: "12:00"
      done: "12:30"
      input: (
        "
        # Context from my IDE setup:
        ## Active file: /work/app/main.nu
        ## My request:
        short form
        "
        | str dedent
      )
      expected: "short form"
    }
    {
      name: "TUI IDE context"
      clock: "13:00"
      done: "13:30"
      input: (
        "
        # Context from my IDE setup:

        ## Active file: src/lib.rs

        ## My request for Codex:
        long form
        "
        | str dedent
      )
      expected: "long form"
    }
    {
      name: "no heading"
      clock: "14:00"
      done: "14:30"
      input: "no heading here"
      expected: "no heading here"
    }
    {
      name: "inline mention"
      clock: "15:00"
      done: "15:30"
      input: "quote ## My request: tail"
      expected: "tail"
    }
  ]
  let records = ($cases | each {|c| codex-turn $c.clock $c.input --done $c.done } | flatten)
  codex-transcript $dir {id: request, cwd: /work/app, thread_source: user} $records

  let day = (digest-day $dir --excerpt-chars 0)
  let prompts = ($day.sessions.0.prompts | get text)

  for c in ($cases | enumerate) {
    assert equal ($prompts | get $c.index) $c.item.expected $c.item.name
  }
}

def "test a negative excerpt length is rejected" [] {
  let dir = (mktemp --directory)

  let run = (digest-run $dir --excerpt-chars=-1)

  assert equal $run.exit_code 1
  assert str contains $run.stderr "must be 0 or greater"
}
