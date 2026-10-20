#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join activity-digest.nu)

const DAY = "2026-10-15"
const HUMAN = {origin: {kind: human}}

# A clock time on the reported day, or a full date and time
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

# A turn's task start, followed by its prompt if it has `text` and its completion at a `done` time
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

# Run the digest in UTC, so the fixtures' `Z` timestamps read as local times.
def digest [dir: string, overrides: record = {}]: nothing -> record {
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
  | save $config_file

  let run = (
    with-env {TZ: UTC} { ^$nu.current-exe --no-config-file $SCRIPT $config_file $DAY | complete }
  )
  assert equal $run.exit_code 0 $run.stderr

  $run.stdout | from json | get days.0
}

def "test only prompts a person typed count" [] {
  let dir = (mktemp --directory)
  let app = "/work/app"
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $app "10:00" "fix the parser")
    (claude-notification $app "11:00")
    (claude-user $app "12:00" "Another Claude session sent a message:" {isMeta: true})
    (claude-user $app "13:00" '<teammate-message teammate_id="a">hi</teammate-message>')
    (claude-user $app "14:00" "<command-name>/review</command-name>")
  ]
  codex-transcript $dir {id: user, cwd: $app, thread_source: user} (codex-turn "16:00" "check CI")
  codex-transcript $dir {id: import, cwd: $app} (codex-turn "17:00" "imported")
  transcript $dir [omp sessions app a.jsonl] [
    {type: session, id: omp, cwd: $app}
    (omp-user "18:00" "plan it")
  ]

  let day = (digest $dir)

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
    (claude-user /work/app "10:00" "From the lead: continue" ($HUMAN | insert teamName t))
    (claude-reply /work/app "10:30")
  ]
  transcript $dir [claude projects app lead subagents agent-a.jsonl] [
    (claude-user /work/app/.claude/worktrees/agent-a "11:00" "Review it" {isSidechain: true})
    {type: assistant, timestamp: (at "11:30"), message: $handback}
  ]
  transcript $dir [claude projects lib headless.jsonl] [
    (claude-user /work/lib "13:00" "Reply with exactly: OK" {entrypoint: sdk-cli})
    (claude-reply /work/lib "13:15")
  ]
  codex-transcript $dir {id: exec, cwd: /work/cli, thread_source: user, source: exec} [
    ...(codex-turn "14:00" "probe" --done "14:30")
  ]
  codex-transcript $dir {id: sub, cwd: /work/cli, thread_source: subagent} [
    ...(codex-turn "15:00" "review the diff" --done "15:30")
  ]

  let day = (digest $dir)

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

  let day = (digest $dir)

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

  let day = (digest $dir)

  assert equal ($day.sessions | select cwd project) [{cwd: $worktree, project: app}]
  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 1.0, projects: {app: 1.0}}
  }
}

def "test the host context covers every project except personal ones" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [(claude-prompt /work/app "10:00" "ship")]
  transcript $dir [claude projects cfg b.jsonl] [(claude-prompt /work/nixos-config "11:00" "tidy")]
  transcript $dir [claude projects notes c.jsonl] [(claude-prompt /work/notes "12:00" "file")]

  let day = (digest $dir {context: work, personalProjects: [nixos-config notes]})

  assert equal ($day.sessions | select project context) [
    {project: app, context: work}
    {project: nixos-config, context: personal}
    {project: notes, context: personal}
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

  let day = (digest $dir {readingMinutes: 12})

  assert equal $day.hours.human {total: 2.2, projects: {app: 2.0, lib: 0.2}}
}

def "test steering prompts and triggers share the first reply" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "start")
    (claude-prompt /work/app "10:05" "also check tests")
    (claude-notification /work/app "10:08")
    (claude-reply /work/app "10:30")
  ]

  let day = (digest $dir)

  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 0.5, projects: {app: 0.5}}
  }
  assert equal $day.sessions.0.replies [{at: "10:30", text: done}]
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

  let day = (digest $dir)

  assert equal $day.hours.agent {total: 2.0, projects: {app: 1.5, lib: 0.5}}
}

def "test a turn without a reply earns no agent time" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    (claude-reply /work/app "10:30")
    (claude-notification /work/app "11:00")
  ]

  let day = (digest $dir)

  assert equal $day.hours.agent {total: 0.5, projects: {app: 0.5}}
}

def "test an agent turn earns at most the cap" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    (claude-reply /work/app "13:00")
  ]

  let day = (digest $dir {agentMaxMinutes: 90})

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

  let day = (digest $dir)

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

  let day = (digest $dir)

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

  let day = (digest $dir)

  assert equal ($day.sessions.0.replies | select at text) [
    {at: "10:12", text: started}
    {at: "00:30", text: merged}
  ]
}
