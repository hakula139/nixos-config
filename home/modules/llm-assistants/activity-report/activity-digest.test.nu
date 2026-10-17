#!/usr/bin/env nu

# ==================================================================================================
# Activity Digest Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join activity-digest.nu)

const DAY = "2026-10-15"
const HUMAN = {origin: {kind: human}}

def at [clock: string]: nothing -> string {
  $"($DAY)T($clock):00.000Z"
}

def transcript [home: string, path: list<string>, records: list]: nothing -> nothing {
  let file = ($home | path join ...$path)
  mkdir ($file | path dirname)
  $records | each { to json --raw } | str join "\n" | save $file
}

def claude-user [cwd: string, clock: string, text: string, extra: record = {}]: nothing -> record {
  {type: user, cwd: $cwd, timestamp: (at $clock), message: {role: user, content: $text}}
  | merge $extra
}

def claude-reply [cwd: string, clock: string, text: string]: nothing -> record {
  let message = {stop_reason: end_turn, content: [{type: text, text: $text}]}
  {type: assistant, cwd: $cwd, timestamp: (at $clock), message: $message}
}

def codex-transcript [home: string, meta: record, prompts: list<record>]: nothing -> nothing {
  let records = (
    $prompts
    | each {|p|
      let item = {type: UserMessage, content: [{type: text, text: $p.text}]}
      {type: event_msg, timestamp: (at $p.clock), payload: {type: item_completed, item: $item}}
    }
  )
  let path = [.codex sessions "2026" "10" "15" $"($meta.id).jsonl"]
  transcript $home $path ([{type: session_meta, payload: $meta}] ++ $records)
}

# Run the digest in UTC, so the fixtures' `Z` timestamps read as local times.
def digest [home: string, context: string = "personal"]: nothing -> record {
  let config = ($home | path join config.json)
  {context: $context, gitRoots: []} | to json | save $config

  let run = (
    with-env {HOME: $home, TZ: UTC} {
      ^$nu.current-exe --no-config-file $SCRIPT $config $DAY | complete
    }
  )
  assert equal $run.exit_code 0 $run.stderr

  $run.stdout | from json | get days.0
}

def "test only prompts a person typed count" [] {
  let home = (mktemp --directory)
  let app = "/work/app"
  transcript $home [.claude projects app lead.jsonl] [
    (claude-user $app "10:00" "fix the parser" $HUMAN)
    (claude-user $app "11:00" "<task-notification>" {origin: {kind: task-notification}})
    (claude-user $app "12:00" "Another Claude session sent a message:" {isMeta: true})
    (claude-user $app "13:00" '<teammate-message teammate_id="a">hi</teammate-message>')
    (claude-user $app "14:00" "<command-name>/review</command-name>")
  ]
  transcript $home [.claude projects app teammate.jsonl] [
    (claude-user $app "15:00" "From the lead: continue" ($HUMAN | insert teamName t))
  ]
  transcript $home [.claude projects app headless.jsonl] [
    (claude-user $app "15:30" "Reply with exactly: OK" {entrypoint: sdk-cli})
  ]
  codex-transcript $home {id: user, cwd: $app, thread_source: user} [
    {clock: "16:00", text: "check CI"}
  ]
  codex-transcript $home {id: import, cwd: $app} [{clock: "17:00", text: "imported"}]
  codex-transcript $home {id: exec, cwd: $app, thread_source: user, source: exec} [
    {clock: "17:30", text: "probe"}
  ]
  let omp_prompt = {role: user, attribution: user, content: "plan it"}
  transcript $home [.omp agent sessions app s.jsonl] [
    {type: session, id: omp, cwd: $app}
    {type: message, timestamp: (at "18:00"), message: $omp_prompt}
  ]

  let day = (digest $home)

  assert equal ($day.sessions | each {|s| {tool: $s.tool, prompts: ($s.prompts | get at)} }) [
    {tool: claude, prompts: ["10:00" "14:00"]}
    {tool: codex, prompts: ["16:00"]}
    {tool: omp, prompts: ["18:00"]}
  ]
}

def "test half hours with a prompt count once per session and once per day" [] {
  let home = (mktemp --directory)
  transcript $home [.claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "start" $HUMAN)
    (claude-reply /work/app "10:05" "working")
    (claude-reply /work/app "10:20" "started")
    (claude-user /work/app "10:29" "more" $HUMAN)
    (claude-user /work/app "10:30" "and this" $HUMAN)
    (claude-user /work/app "14:45" "next" $HUMAN)
    (claude-user /work/app "15:30" "<task-notification>" {origin: {kind: task-notification}})
    (claude-reply /work/app "23:00" "merged")
  ]
  transcript $home [.claude projects lib b.jsonl] [
    (claude-user /work/lib "10:10" "review" $HUMAN)
    (claude-user /work/lib "16:00" "merge" $HUMAN)
  ]

  let day = (digest $home)

  assert equal ($day.sessions | get active_hours) [1.5 1.0]
  assert equal $day.active_hours {personal: 2.0}
  assert equal ($day.sessions.0.replies | get at) ["10:20" "23:00"]
}

def "test host context covers every project except nixos-config" [] {
  let home = (mktemp --directory)
  let worktree = "/home/me/nixos-config/.claude/worktrees/fix"
  transcript $home [.claude projects app a.jsonl] [(claude-user /work/app "10:00" "ship" $HUMAN)]
  transcript $home [.claude projects cfg b.jsonl] [
    (claude-user $worktree "10:00" "tidy" $HUMAN)
    (claude-user $worktree "11:00" "merge" $HUMAN)
  ]

  let day = (digest $home work)

  assert equal ($day.sessions | select project context) [
    {project: app, context: work}
    {project: nixos-config, context: personal}
  ]
  assert equal $day.active_hours {work: 0.5, personal: 1.0}
}

def "test workmux workers are left out" [] {
  let home = (mktemp --directory)
  transcript $home [.claude projects app a.jsonl] [
    (claude-user /work/app "10:00" "delegate" $HUMAN)
  ]
  transcript $home [.claude projects worker w.jsonl] [
    (claude-user /work/app__worktrees/fix "11:00" "# Task: fix it" $HUMAN)
  ]

  let day = (digest $home)

  assert equal ($day.sessions | get cwd) [/work/app]
  assert equal $day.active_hours {personal: 0.5}
}
