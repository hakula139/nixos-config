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

def at [clock: string]: nothing -> string {
  $"($DAY)T($clock):00.000Z"
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

def codex-transcript [dir: string, meta: record, prompts: list<record>]: nothing -> nothing {
  let records = (
    $prompts
    | each {|p|
      let item = {type: UserMessage, content: [{type: text, text: $p.text}]}
      {type: event_msg, timestamp: (at $p.clock), payload: {type: item_completed, item: $item}}
    }
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
    worktreePatterns: ['/\.claude/worktrees/[^/]+.*$']
    personalProjects: [nixos-config]
    readingMinutes: 10
    maxMinutes: 60
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

  assert equal $day.hours {total: 2.2, projects: {app: 2.0, lib: 0.2}}
}

def "test a day keeps its final replies past midnight until the next prompt" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "start" $HUMAN)
    (claude-reply /work/app "10:05" "working")
    (claude-reply /work/app "10:12" "started")
    (claude-user /work/app "10:15" "ship it" $HUMAN)
    (claude-reply /work/app "00:30" "merged" | update timestamp "2026-10-16T00:30:00.000Z")
    (claude-user /work/app "09:00" "next" $HUMAN | update timestamp "2026-10-16T09:00:00.000Z")
    (claude-reply /work/app "09:05" "tomorrow" | update timestamp "2026-10-16T09:05:00.000Z")
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

def "test sessions in excluded directories are left out" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "delegate" $HUMAN)
  ]
  transcript $dir [claude projects worker w.jsonl] [
    (claude-user /work/app__worktrees/fix "11:00" "# Task: fix it" $HUMAN)
  ]
  transcript $dir [claude projects probe p.jsonl] [
    (claude-user /tmp/probe "12:00" "try it" $HUMAN)
  ]

  let day = (digest $dir {excludedDirs: [__worktrees/ '^/tmp/']})

  assert equal ($day.sessions | get cwd) [/work/app]
  assert equal ($day.hours.projects | columns) [app]
}
