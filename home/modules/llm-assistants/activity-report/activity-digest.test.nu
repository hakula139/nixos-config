#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join activity-digest.nu)

const DAY = "2026-10-15"
const HUMAN = {origin: {kind: human}}
const NOTIFIED = {origin: {kind: task-notification}}

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

def claude-reply [cwd: string, clock: string, text: string = "done"]: nothing -> record {
  let message = {stop_reason: end_turn, content: [{type: text, text: $text}]}
  {type: assistant, cwd: $cwd, timestamp: (at $clock), message: $message}
}

def codex-event [clock: string, payload: record]: nothing -> record {
  {type: event_msg, timestamp: (at $clock), payload: $payload}
}

# Each turn starts a task, with a prompt if it has `text`, completed if it has a `done` time.
def codex-transcript [dir: string, meta: record, turns: list<record>]: nothing -> nothing {
  let records = (
    $turns
    | each {|t|
      let item = {type: UserMessage, content: [{type: text, text: $t.text?}]}
      [
        (codex-event $t.clock {type: task_started})
        (if $t.text? != null { codex-event $t.clock {type: item_completed, item: $item} })
        (if $t.done? != null { codex-event $t.done {type: task_complete, last_agent_message: ok} })
      ]
      | compact
    }
    | flatten
  )
  let path = [codex sessions "2026" "10" "15" $"($meta.id).jsonl"]
  transcript $dir $path ([{type: session_meta, payload: $meta}] ++ $records)
}

# Run the digest in UTC, so the fixtures' `Z` timestamps read as local times.
def digest [dir: string, overrides: record = {}]: nothing -> record {
  let config_file = ($dir | path join config.json)
  {
    context: personal
    excludedDirs: [__worktrees/]
    worktreePatterns: ['/\.claude/worktrees/[^/]+.*$' '__worktrees/[^/]+.*$']
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
  transcript $dir [claude projects app lead.jsonl] [
    (claude-user $app "10:00" "fix the parser" $HUMAN)
    (claude-user $app "11:00" "<task-notification>" $NOTIFIED)
    (claude-user $app "12:00" "Another Claude session sent a message:" {isMeta: true})
    (claude-user $app "13:00" '<teammate-message teammate_id="a">hi</teammate-message>')
    (claude-user $app "14:00" "<command-name>/review</command-name>")
  ]
  transcript $dir [claude projects app teammate.jsonl] [
    (claude-user $app "15:00" "From the lead: continue" ($HUMAN | insert teamName t))
  ]
  transcript $dir [claude projects app headless.jsonl] [
    (claude-user $app "15:30" "Reply with exactly: OK" {entrypoint: sdk-cli})
  ]
  codex-transcript $dir {id: user, cwd: $app, thread_source: user} [
    {clock: "16:00", text: "check CI"}
  ]
  codex-transcript $dir {id: import, cwd: $app} [{clock: "17:00", text: "imported"}]
  codex-transcript $dir {id: exec, cwd: $app, thread_source: user, source: exec} [
    {clock: "17:30", text: "probe"}
  ]
  let omp_prompt = {role: user, attribution: user, content: "plan it"}
  transcript $dir [omp sessions app s.jsonl] [
    {type: session, id: omp, cwd: $app}
    {type: message, timestamp: (at "18:00"), message: $omp_prompt}
  ]

  let day = (digest $dir)

  assert equal ($day.sessions | each {|s| {tool: $s.tool, prompts: ($s.prompts | get at)} }) [
    {tool: claude, prompts: ["10:00" "14:00"]}
    {tool: codex, prompts: ["16:00"]}
    {tool: omp, prompts: ["18:00"]}
  ]
}

def "test a prompt earns its turn and a reading allowance until the next prompt anywhere" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "release it, I'll watch" $HUMAN)
    (claude-reply /work/app "11:30")
    (claude-user /work/app "12:00" "fix the test" $HUMAN)
    (claude-reply /work/app "12:06")
    (claude-user /work/app "13:00" "refactor the parser" $HUMAN)
    (claude-reply /work/app "13:45")
    (claude-user /work/app "14:00" "merge it" $HUMAN)
    (claude-reply /work/app "14:06")
    (claude-user /work/app "14:30" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "14:50")
  ]
  transcript $dir [claude projects lib b.jsonl] [
    (claude-user /work/lib "13:24" "review the API" $HUMAN)
  ]

  let day = (digest $dir {readingMinutes: 12})

  assert equal $day.hours.human {total: 2.2, projects: {app: 2.0, lib: 0.2}}
}

def "test a notification turn earns agent time but no human time" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "fix it" $HUMAN)
    (claude-reply /work/app "10:30")
    (claude-user /work/app "12:00" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "12:30")
  ]

  let day = (digest $dir)

  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 1.0, projects: {app: 1.0}}
  }
}

def "test parallel agents on a project count once" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "build it" $HUMAN)
    (claude-reply /work/app "11:00")
  ]
  let omp_task = {role: user, attribution: agent, content: "build the API"}
  let omp_reply = {role: assistant, stopReason: stop, content: "built"}
  transcript $dir [omp sessions app b.jsonl] [
    {type: session, id: omp, cwd: /work/app}
    {type: message, timestamp: (at "10:30"), message: $omp_task}
    {type: message, timestamp: (at "11:30"), message: $omp_reply}
  ]
  transcript $dir [claude projects lib c.jsonl] [
    (claude-user /work/lib "10:00" "<task-notification>" $NOTIFIED)
    (claude-reply /work/lib "10:30")
  ]

  let day = (digest $dir)

  assert equal $day.hours.agent {total: 2.0, projects: {app: 1.5, lib: 0.5}}
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
  transcript $dir [claude projects worker w.jsonl] [
    (claude-user /work/app__worktrees/fix "12:00" "# Task: fix it" $HUMAN)
    (claude-reply /work/app__worktrees/fix "12:30")
  ]
  transcript $dir [claude projects lib headless.jsonl] [
    (claude-user /work/lib "13:00" "Reply with exactly: OK" {entrypoint: sdk-cli})
    (claude-reply /work/lib "13:15")
  ]
  codex-transcript $dir {id: exec, cwd: /work/cli, thread_source: user, source: exec} [
    {clock: "14:00", text: "probe", done: "14:30"}
  ]
  codex-transcript $dir {id: sub, cwd: /work/cli, thread_source: subagent} [
    {clock: "15:00", done: "15:30"}
  ]

  let day = (digest $dir)

  assert equal $day.sessions []
  assert equal $day.hours {
    human: {total: 0.0, projects: {}}
    agent: {total: 2.75, projects: {app: 1.5, lib: 0.25, cli: 1.0}}
  }
}

def "test a turn without a reply earns no agent time" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "10:30")
    (claude-user /work/app "11:00" "<task-notification>" $NOTIFIED)
  ]

  let day = (digest $dir)

  assert equal $day.hours.agent {total: 0.5, projects: {app: 0.5}}
}

def "test canceled Codex turns cannot borrow a later reply" [] {
  let dir = (mktemp --directory)
  let meta = {id: canceled, cwd: /work/app, thread_source: user}
  let prompt = {type: UserMessage, content: [{type: text, text: "start"}]}
  transcript $dir [codex sessions "2026" "10" "15" canceled.jsonl] [
    {type: session_meta, payload: $meta}
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

def "test steering prompts and triggers share the first reply" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "start" $HUMAN)
    (claude-user /work/app "10:05" "also check tests" $HUMAN)
    (claude-user /work/app "10:08" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "10:30" "done")
  ]

  let day = (digest $dir)

  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 0.5, projects: {app: 0.5}}
  }
  assert equal $day.sessions.0.replies [{at: "10:30", text: done}]
}

def "test nested OMP advisors extend agent hours without human excerpts" [] {
  let dir = (mktemp --directory)
  let prompt = {role: user, attribution: user, content: "review it"}
  let task = {role: user, attribution: agent, content: "check the API"}
  let reply = {role: assistant, stopReason: stop, content: "done"}
  transcript $dir [omp sessions app parent.jsonl] [
    {type: session, id: parent, cwd: /work/app}
    {type: message, timestamp: (at "10:00"), message: $prompt}
    {type: message, timestamp: (at "10:30"), message: $reply}
  ]
  transcript $dir [omp sessions app parent __advisor.jsonl] [
    {type: session, id: advisor, cwd: /work/app}
    {type: message, timestamp: (at "10:15"), message: $task}
    {type: message, timestamp: (at "11:00"), message: $reply}
  ]

  let day = (digest $dir)

  assert equal $day.hours {
    human: {total: 0.67, projects: {app: 0.67}}
    agent: {total: 1.0, projects: {app: 1.0}}
  }
  assert equal ($day.sessions | get session) [parent]
  assert equal $day.sessions.0.replies [{at: "10:30", text: done}]
}

def "test an agent turn earns at most the cap" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "13:00")
  ]

  let day = (digest $dir {agentMaxMinutes: 90})

  assert equal $day.hours.agent {total: 1.5, projects: {app: 1.5}}
}

def "test agent turns across midnight count only within the day" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "2026-10-14T23:30" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "00:30")
    (claude-user /work/app "23:00" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "2026-10-16T01:00")
  ]

  let day = (digest $dir)

  assert equal $day.hours.agent {total: 1.5, projects: {app: 1.5}}
}

def "test a day keeps its final replies past midnight until the next prompt" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "start" $HUMAN)
    (claude-reply /work/app "10:05" "working")
    (claude-user /work/app "10:08" "<task-notification>" $NOTIFIED)
    (claude-reply /work/app "10:12" "started")
    (claude-user /work/app "10:15" "ship it" $HUMAN)
    (claude-reply /work/app "2026-10-16T00:30" "merged")
    (claude-user /work/app "2026-10-16T09:00" "next" $HUMAN)
    (claude-reply /work/app "2026-10-16T09:05" "tomorrow")
  ]

  let day = (digest $dir)

  assert equal ($day.sessions.0.replies | select at text) [
    {at: "10:12", text: started}
    {at: "00:30", text: merged}
  ]
}

def "test the host context covers every project except personal ones" [] {
  let dir = (mktemp --directory)
  let worktree = "/home/me/nixos-config/.claude/worktrees/fix"
  transcript $dir [claude projects app a.jsonl] [(claude-user /work/app "10:00" "ship" $HUMAN)]
  transcript $dir [claude projects cfg b.jsonl] [(claude-user $worktree "11:00" "tidy" $HUMAN)]
  transcript $dir [claude projects notes c.jsonl] [(claude-user /work/notes "12:00" "file" $HUMAN)]

  let day = (digest $dir {context: work, personalProjects: [nixos-config notes]})

  assert equal ($day.sessions | select project context) [
    {project: app, context: work}
    {project: nixos-config, context: personal}
    {project: notes, context: personal}
  ]
}
