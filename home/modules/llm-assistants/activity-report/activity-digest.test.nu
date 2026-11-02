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

# A repository whose checkout the digest can find, ignoring agent scratch like the real ones.
def git-repo [dir: string, name: string]: nothing -> string {
  let path = ($dir | path join $name)
  mkdir $path
  ^git -C $path init --quiet
  (
    "
    .claude/worktrees/
    .claude/agent-memory-local/

    "
    | str dedent
  ) | save ($path | path join .gitignore)
  ^git -C $path add .gitignore
  ^git -C $path -c user.name=test -c user.email=test@test commit --quiet -m init
  $path | path expand
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

# An AskUserQuestion result carries the answers the person gave, keyed by question.
def claude-answered [cwd: string, clock: string, answers: record]: nothing -> record {
  let content = [{type: tool_result, content: "The user answered.", tool_use_id: tool}]
  let result = {questions: [], answers: $answers, annotations: {}}
  let message = {role: user, content: $content}
  {type: user, cwd: $cwd, timestamp: (at $clock), isSidechain: false, message: $message}
  | insert toolUseResult $result
}

# An unanswered question carries no answers, and names the timeout that ended it.
def claude-timed-out [cwd: string, clock: string]: nothing -> record {
  let content = [{type: tool_result, content: "No response after 300s.", tool_use_id: tool}]
  let result = {questions: [], answers: {}, afkTimeoutMs: 300000, annotations: {}}
  let message = {role: user, content: $content}
  {type: user, cwd: $cwd, timestamp: (at $clock), isSidechain: false, message: $message}
  | insert toolUseResult $result
}

def claude-reply [cwd: string, clock: string, text: string = "done"]: nothing -> record {
  let message = {stop_reason: end_turn, content: [{type: text, text: $text}]}
  {type: assistant, cwd: $cwd, timestamp: (at $clock), message: $message}
}

# Assistant records through a turn, since a gap longer than 30 minutes ends its span.
def claude-active [cwd: string, clocks: list<string>]: nothing -> list<record> {
  $clocks
  | each {|clock|
    let message = {stop_reason: null, content: [{type: thinking, thinking: ""}]}
    {type: assistant, cwd: $cwd, timestamp: (at $clock), message: $message}
  }
}

def claude-tool [cwd: string, clock: string, name: string, input: record]: nothing -> record {
  let content = [{type: tool_use, id: tool, name: $name, input: $input}]
  let message = {role: assistant, stop_reason: tool_use, content: $content}
  {type: assistant, cwd: $cwd, timestamp: (at $clock), message: $message}
}

def claude-subagent [
  dir: string
  project: string
  lead: string
  id: string
  meta: record
  records: list
]: nothing -> nothing {
  transcript $dir [claude projects $project $lead subagents $"agent-($id).jsonl"] $records
  let path = [$dir claude projects $project $lead subagents $"agent-($id).meta.json"]
  $meta | to json | save --force ($path | path join)
}

def codex-transcript [
  dir: string
  meta: record
  records: list<record>
  --archived
  --compressed
]: nothing -> nothing {
  let path = (
    if $archived {
      [codex archived_sessions $"rollout-($DAY)T00-00-00-($meta.id).jsonl"]
    } else {
      [codex sessions ...($DAY | split row -) $"rollout-($DAY)T00-00-00-($meta.id).jsonl"]
    }
  )
  transcript $dir $path ([{type: session_meta, payload: $meta}] ++ $records)
  if $compressed {
    ^zstd --quiet --force --rm ($dir | path join ...$path)
  }
}

def codex-event [clock: string, payload: record]: nothing -> record {
  {type: event_msg, timestamp: (at $clock), payload: $payload}
}

def codex-model [clock: string]: nothing -> record {
  let payload = {type: message, role: assistant, content: [{type: output_text, text: ""}]}
  {type: response_item, timestamp: (at $clock), payload: $payload}
}

# A turn's task start, its prompt a second later with `text`, and its completion at a `done` time.
def codex-turn [clock: string, text?: string, --done: string]: nothing -> list<record> {
  let id = $"turn-($clock)"
  let item = {type: UserMessage, content: [{type: text, text: $text}]}
  let prompt_at = ((at $clock | into datetime) + 1sec | format date "%Y-%m-%dT%H:%M:%S%.3fZ")
  [
    (codex-event $clock {type: task_started, turn_id: $id})
    (
      if $text != null {
        {
          type: event_msg
          timestamp: $prompt_at
          payload: {type: item_completed, item: $item, turn_id: $id}
        }
      }
    )
    (if $done != null { codex-event $done {type: task_complete, last_agent_message: ok} })
  ]
  | compact
}

def codex-file-change [clock: string, changes: record]: nothing -> record {
  let item = {type: FileChange, id: change, status: completed, changes: $changes}
  codex-event $clock {type: item_completed, item: ($item | merge {stdout: "", stderr: ""})}
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

def omp-tool [clock: string, calls: list]: nothing -> record {
  let message = {role: assistant, stopReason: toolUse, content: $calls}
  {type: message, timestamp: (at $clock), message: $message}
}

def digest-run [
  dir: string
  overrides: record = {}
  --excerpt-chars: int = 400
  --from: string
  --to: string
  --tz: string = "UTC"
]: nothing -> record {
  let config_file = ($dir | path join config.json)
  {
    excludedDirs: ['/\.claude/worktrees/workmux/']
    labels: {default: [work], projects: {nixos-config: [personal]}}
    readingMinutes: 10
    maxMinutes: 60
    agentMaxMinutes: 120
    agentIdleMinutes: 30
    assistantDirs: {
      claude: ($dir | path join claude)
      codex: ($dir | path join codex)
      omp: ($dir | path join omp)
    }
  }
  | merge $overrides
  | to json
  | save --force $config_file

  let args = (
    (["--config" $config_file ($from | default $DAY) $to] | compact)
    ++ [$"--excerpt-chars=($excerpt_chars)"]
  )
  with-env {TZ: $tz} { ^$nu.current-exe --no-config-file $SCRIPT ...$args | complete }
}

def digest-output [
  dir: string
  overrides: record = {}
  --excerpt-chars: int = 400
  --from: string
  --to: string
  --tz: string = "UTC"
]: nothing -> record {
  let run = (
    digest-run $dir $overrides --excerpt-chars=$excerpt_chars --from=$from --to=$to --tz=$tz
  )
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

def "test a renamed lead session keeps its prompts" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    {type: agent-name, agentName: design-log, sessionId: a}
    (claude-prompt /work/app "10:00" "start")
    (claude-reply /work/app "10:20" "done")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions | each {|s| $s.prompts | select at hours }) [
    [{at: "10:00", hours: 0.5}]
  ]
  assert equal $day.runs []
}

def "test an answered question earns a prompt and a timed-out one earns none" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-answered /work/app "10:00" {"Which repo?": app, "Which branch?": main})
    (claude-reply /work/app "10:06" "shipped")
    (claude-timed-out /work/app "11:00")
    (claude-reply /work/app "11:06" "carried on")
  ]

  let day = (digest-day $dir --excerpt-chars 0)

  assert equal ($day.sessions.0.prompts | select text hours agent) [
    {
      text: (
        "
        Which repo?: app
        Which branch?: main
        "
        | str dedent
      )
      hours: 0.2667
      agent: 0.1
    }
  ]
}

def "test a prompt queued while a question waits keeps its own unit" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "start")
    (claude-answered /work/app "10:05" {"Which repo?": app})
    (claude-queued /work/app "10:03" "also run the tests")
    (claude-reply /work/app "10:20" "done")
  ]

  let day = (digest-day $dir --excerpt-chars 0)

  assert equal ($day.sessions.0.prompts | select at agent) [
    {at: "10:00", agent: 0.05}
    {at: "10:03", agent: 0.0333}
    {at: "10:05", agent: 0.25}
  ]
}

def "test records written out of order keep their time order" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "first")
    (claude-reply /work/app "10:20" "done")
    (claude-prompt /work/app "10:05" "second")
  ]

  let day = (digest-day $dir --excerpt-chars 0)

  assert equal ($day.sessions.0.prompts | select at text agent) [
    {at: "10:00", text: first, agent: 0.0833}
    {at: "10:05", text: second, agent: 0.25}
  ]
  assert equal $day.sessions.0.replies [{at: "10:20", text: done}]
}

def "test only a record tool result can be a question" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-user /work/app "09:58" "ran a command" {toolUseResult: output})
    (claude-user /work/app "09:59" "read a file" {toolUseResult: [{type: text, text: x}]})
    (claude-prompt /work/app "10:00" "start")
    (claude-reply /work/app "10:10" "done")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions.0.prompts | select at hours) [{at: "10:00", hours: 0.3333}]
}

def "test each tool's writes credit their prompt's repositories" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  mkdir ($app | path join src)

  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $app "10:00" "ship the parser")
    (claude-tool $app "10:01" Edit {
      file_path: ($app | path join src a.nu)
      old_string: a
      new_string: b
      replace_all: false
    })
    (claude-tool $app "10:02" Edit {
      file_path: ($app | path join src a.nu)
      old_string: b
      new_string: c
      replace_all: false
    })
    (claude-tool $app "10:03" Write {file_path: ($lib | path join b.nu), content: b})
    (claude-tool $app "10:04" NotebookEdit {
      notebook_path: ($lib | path join n.ipynb)
      cell_id: cell
      new_source: x
    })
  ]
  let changes = (
    [($app | path join c.rs) ($app | path join e.rs) ($lib | path join d.rs)]
    | reduce --fold {} {|path, acc| $acc | insert $path {type: add, content: x} }
  )
  codex-transcript $dir {id: codex, cwd: $app, thread_source: user} (
    (codex-turn "11:00" "write files") ++ [(codex-file-change "11:01" $changes)]
  )
  transcript $dir [omp sessions app a.jsonl] [
    {type: session, id: omp, cwd: $app}
    (omp-user "12:00" "write files")
    (omp-tool "12:01" [
      {
        type: toolCall
        id: w
        name: write
        arguments: {path: src/f.ts, content: f, i: ""}
      }
      {
        type: toolCall
        id: e
        name: edit
        arguments: {
          path: ($lib | path join g.ts)
          old_string: a
          new_string: b
          i: ""
        }
      }
      {
        type: toolCall
        id: p
        name: edit
        arguments: {
          input: (
            "
            [ src/h.ts#1A2B ]
            PUT 1.=1:
            +x
            [src/f.ts#9C29]
            PUT 2.=2:
            +y
            "
            | str dedent
          )
          i: ""
        }
      }
    ])
  ]

  let cases = [
    {tool: claude, repos: {lib: 0.67, app: 0.33}}
    {tool: codex, repos: {app: 0.67, lib: 0.33}}
    {tool: omp, repos: {app: 0.67, lib: 0.33}}
  ]

  let day = (digest-day $dir)

  for c in $cases {
    assert equal ($day.sessions | where tool == $c.tool | get 0.prompts.0.repos) $c.repos $c.tool
  }
}

def "test Claude subagents, forks, and teammates credit the prompt whose turn started them" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  let docs = (git-repo $dir docs)
  mkdir ($app | path join src)
  let lead = "1a2b3c4d-0000-4000-8000-000000000001"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "10:00" "P1")
    (claude-reply $app "10:10" "first")
    (claude-prompt $app "10:20" "P2")
    (claude-reply $app "10:25" "second")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "10:01" "task" {isSidechain: true})
    ...(claude-active $app ["10:03"])
    (claude-user $app "10:15" "relay" {isSidechain: true, isMeta: true, origin: {kind: human}})
    (claude-tool $app "10:21" Edit {
      file_path: ($lib | path join parser.nu)
      old_string: a
      new_string: b
      replace_all: false
    })
    (claude-tool $app "10:22" SubagentHandback {})
    (claude-user $app "10:26" "continue" {isSidechain: true})
    (claude-tool $app "10:27" Write {file_path: ($docs | path join README.md), content: x})
    (claude-tool $app "10:28" SubagentHandback {})
  ]
  claude-subagent $dir app $lead f {
    agentType: fork
    isFork: true
    parentAgentId: a
    spawnDepth: 2
  } [
    (claude-user $app "10:21" "fork" {isSidechain: true})
    (claude-tool $app "10:21" Write {file_path: ($app | path join src fork.nu), content: x})
    (claude-tool $app "10:23" SubagentHandback {})
  ]
  let teammate = '<teammate-message teammate_id="team-lead">work</teammate-message>'
  transcript $dir [claude projects app "99999999-0000-4000-8000-000000000001.jsonl"] [
    (claude-user $app "10:05" $teammate {teamName: "session-1a2b3c4d", agentName: fix})
    (claude-tool $app "10:06" Write {file_path: ($lib | path join team.nu), content: x})
    (claude-reply $app "10:07" "done")
  ]

  let day = (digest-day $dir)

  assert equal $day.sessions.0.prompts.0.repos {lib: 0.67, app: 0.33}
  assert equal $day.sessions.0.prompts.0.agent 0.5833
  assert equal $day.sessions.0.prompts.1.repos {docs: 1.0}
  assert equal $day.sessions.0.prompts.1.agent 0.1167
  assert equal $day.runs []
}

def "test Codex subagents and guardian reviews credit the prompt that started them" [] {
  for compressed in [false true] {
    let dir = (mktemp --directory)
    let app = (git-repo $dir app)
    let lib = (git-repo $dir lib)
    let form = if $compressed { "compressed" } else { "plain" }
    codex-transcript $dir {id: lead, cwd: $app, thread_source: user} (
      codex-turn "11:00" "review it" --done "11:10"
    ) --compressed=$compressed
    let changes = (
      [($lib | path join x.rs)] | reduce --fold {} {|path, acc| $acc | insert $path {type: add} }
    )
    let spawn = {parent_thread_id: lead, depth: 1, agent_nickname: x, agent_role: y}
    let sub_records = (
      (codex-turn "11:02" "fix it" --done "11:06")
      ++ [(codex-file-change "11:04" $changes)]
    )
    codex-transcript $dir {
      id: sub
      session_id: lead
      parent_thread_id: lead
      cwd: $app
      thread_source: subagent
      source: {subagent: {thread_spawn: $spawn}}
    } $sub_records --compressed=$compressed
    let guardian_records = (
      (codex-turn "11:05" --done "11:20")
      ++ [(codex-model "11:15")]
    )
    codex-transcript $dir {
      id: guardian
      session_id: sub
      parent_thread_id: sub
      cwd: $app
      thread_source: guardian_review
      source: {subagent: {other: guardian}}
    } $guardian_records --compressed=$compressed

    let day = (digest-day $dir)

    assert equal $day.sessions.0.prompts.0.repos {lib: 1.0} $form
    assert equal $day.sessions.0.prompts.0.agent 0.4828 $form
    assert equal $day.runs [] $form
  }
}

def "test a Codex turn starts at its prompt" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  codex-transcript $dir {id: lead, cwd: $app, thread_source: user} (
    codex-turn "11:00" "review it" --done "11:10"
  )

  let day = (digest-day $dir)

  assert equal $day.runs []
  assert equal $day.sessions.0.prompts.0.agent 0.1664
}

def "test a Codex subagent finds its parent in archived sessions" [] {
  for compressed in [false true] {
    let dir = (mktemp --directory)
    let app = (git-repo $dir app)
    let lib = (git-repo $dir lib)
    let form = if $compressed { "compressed" } else { "plain" }
    codex-transcript $dir {id: lead, cwd: $app, thread_source: user} (
      codex-turn "11:00" "review it" --done "11:10"
    ) --archived --compressed=$compressed
    let changes = (
      [($lib | path join x.rs)] | reduce --fold {} {|path, acc| $acc | insert $path {type: add} }
    )
    codex-transcript $dir {
      id: sub
      cwd: $app
      thread_source: subagent
      parent_thread_id: lead
    } ((codex-turn "11:02" "fix it" --done "11:06") ++ [(codex-file-change "11:04" $changes)])

    let day = (digest-day $dir)

    assert equal $day.sessions.0.prompts.0.repos {lib: 1.0} $form
    assert equal $day.runs [] $form
  }
}

def "test both forms of an archived Codex session read once" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let meta = {id: both, cwd: $app, thread_source: user}
  let records = (codex-turn "11:00" "review it" --done "11:10")
  codex-transcript $dir $meta $records --archived --compressed
  codex-transcript $dir $meta $records --archived

  let day = (digest-day $dir)

  assert equal ($day.sessions | length) 1
  assert equal $day.sessions.0.prompts.0.agent 0.1664
}

def "test OMP subagents and advisors credit the prompt that started them" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  transcript $dir [omp sessions app parent.jsonl] [
    {type: session, id: parent, cwd: $app}
    (omp-user "12:00" "review it")
    (omp-reply "12:10")
  ]
  transcript $dir [omp sessions app parent Fix.jsonl] [
    {type: session, id: fix, cwd: $app, parentSession: parent}
    (omp-user "12:02" "fix it" --agent)
    (omp-tool "12:02" [
      {
        type: toolCall
        id: w
        name: write
        arguments: {
          path: ../lib/y.ts
          content: y
          i: ""
        }
      }
    ])
    (omp-reply "12:05")
  ]
  transcript $dir [omp sessions app parent __advisor.jsonl] [
    {type: session, id: advisor, cwd: $app, parentSession: parent}
    (omp-user "12:06" "advise" --agent)
    (omp-reply "12:30")
  ]

  let day = (digest-day $dir)

  assert equal $day.sessions.0.prompts.0.repos {lib: 1.0}
  assert equal $day.sessions.0.prompts.0.agent 0.6167
  assert equal ($day.sessions | length) 1
  assert equal $day.runs []
}

def "test repositories resolve subdirectories and worktrees, and missing paths resolve to none" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  mkdir ($app | path join src)
  mkdir ($dir | path join app-wt)
  let linked = ($dir | path join app-wt fix)
  ^git -C $app worktree add --detach --quiet $linked
  let live = ($app | path join .claude worktrees live)
  ^git -C $app worktree add --detach --quiet $live
  mkdir ($dir | path join scratch)
  let cases = [
    {
      name: sub
      clock: "10:00"
      cwd: ($app | path join src)
      file: ($app | path join src a.nu)
      repo: app
      repos: {app: 1.0}
    }
    {
      name: linked
      clock: "10:01"
      cwd: $linked
      file: ($linked | path join src b.nu)
      repo: app
      repos: {app: 1.0}
    }
    {
      name: live
      clock: "10:02"
      cwd: $live
      file: ($live | path join c.nu)
      repo: app
      repos: {app: 1.0}
    }
    {
      name: gone
      clock: "10:03"
      cwd: ($app | path join .claude worktrees gone)
      file: ($app | path join .claude worktrees gone d.nu)
      repo: app
      repos: {app: 1.0}
    }
    {
      name: scratch
      clock: "10:04"
      cwd: ($dir | path join scratch)
      file: ($dir | path join scratch e.nu)
      repo: null
      repos: {}
    }
    {
      name: gone-wt
      clock: "10:05"
      cwd: ($dir | path join app-wt gone)
      file: ($dir | path join app-wt gone f.nu)
      repo: null
      repos: {}
    }
  ]
  for c in $cases {
    transcript $dir [claude projects $c.name $"($c.name).jsonl"] [
      (claude-prompt $c.cwd $c.clock "write it")
      (claude-tool $c.cwd $c.clock Write {file_path: $c.file, content: x})
    ]
  }

  let output = (digest-output $dir)
  let day = $output.days.0

  assert equal ($day.sessions | each {|s| {repo: $s.repo, repos: $s.prompts.0.repos} }) (
    $cases | each {|c| {repo: $c.repo, repos: $c.repos} }
  )
  assert equal $output.repositories {app: $app}
}

def "test a checkout behind a symlinked parent keeps its writes" [] {
  let dir = (mktemp --directory)
  mkdir ($dir | path join real)
  let app = (git-repo ($dir | path join real) app)
  mkdir ($app | path join src)
  ^ln -s real ($dir | path join lnk)
  let linked = ($dir | path join lnk app)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $linked "10:00" "ship it")
    (claude-tool $linked "10:01" Write {file_path: ($linked | path join src a.nu), content: x})
    (claude-prompt $linked "10:05" "then the deleted worktree")
    (claude-tool $linked "10:06" Write {
      file_path: ($linked | path join .claude worktrees gone b.nu)
      content: x
    })
  ]

  let output = (digest-output $dir)
  let day = $output.days.0

  assert equal $day.sessions.0.repo app
  assert equal ($day.sessions.0.prompts | get repos) [{app: 1.0} {app: 1.0}]
  assert equal $output.repositories {app: $app}
}

def "test a symlink outside a repository credits the repository it points into" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  mkdir ($lib | path join src)
  mkdir ($dir | path join elsewhere)
  ^ln -s ($lib | path join src) ($dir | path join elsewhere mem)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $app "10:00" "write to the linked tree")
    (claude-tool $app "10:01" Write {
      file_path: ($dir | path join elsewhere mem a.nu)
      content: x
    })
  ]

  let output = (digest-output $dir)

  assert equal ($output.days.0.sessions.0.prompts | get repos) [{lib: 1.0}]
  assert equal $output.repositories.lib $lib
}

def "test writes git ignores count only while their directory exists" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  mkdir ($app | path join src)
  mkdir ($lib | path join .claude agent-memory-local r)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $app "10:00" "write files")
    (claude-tool $app "10:01" Write {file_path: ($app | path join src a.nu), content: x})
    (claude-tool $app "10:02" Write {
      file_path: ($app | path join .claude worktrees gone src b.nu)
      content: x
    })
    (claude-tool $app "10:03" Write {
      file_path: ($lib | path join .claude agent-memory-local r m.md)
      content: x
    })
    (claude-tool $app "10:03" Write {
      file_path: ($lib | path join .claude agent-memory-local r 周报.md)
      content: x
    })
    (claude-tool $app "10:04" Write {file_path: ($lib | path join README.md), content: x})
  ]

  let day = (digest-day $dir)

  assert equal $day.sessions.0.prompts.0.repos {app: 0.67, lib: 0.33}
}

def "test separate prompts and parallel delegates both add agent time" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  let lead = "aaaabbbb-0000-4000-8000-000000000001"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "10:00" "P")
    ...(claude-active $app ["10:20" "10:40"])
    (claude-reply $app "11:00" "first")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "10:10" "task" {isSidechain: true})
    ...(claude-active $app ["10:30"])
    (claude-tool $app "10:50" SubagentHandback {})
  ]
  claude-subagent $dir app $lead b {agentType: implementer, toolUseId: u, spawnDepth: 1} [
    (claude-user $app "10:20" "task" {isSidechain: true})
    ...(claude-active $app ["10:40" "11:00"])
    (claude-tool $app "11:30" SubagentHandback {})
  ]
  transcript $dir [claude projects lib q.jsonl] [
    (claude-prompt $lib "10:30" "Q")
    ...(claude-active $lib ["10:45"])
    (claude-reply $lib "11:00" "second")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions | where cwd == $app | get 0.prompts.0.agent) 2.8333
  assert equal ($day.sessions | where cwd == $lib | get 0.prompts.0.agent) 0.5
}

def "test a delegate turn on a later day continues its prompt there" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  let lead = "aaaabbbb-0000-4000-8000-000000000003"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "22:00" "P")
    (claude-reply $app "22:20" "first")
    (claude-prompt $app "2026-10-16T09:00" "Q")
    (claude-reply $app "2026-10-16T09:30" "second")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "22:30" "task" {isSidechain: true})
    (claude-tool $app "23:00" Write {file_path: ($app | path join src x.nu), content: x})
    (claude-tool $app "23:00" SubagentHandback {})
    (claude-user $app "2026-10-16T00:10" "continue" {isSidechain: true})
    (claude-tool $app "2026-10-16T00:40" Write {file_path: ($lib | path join y.nu), content: y})
    (claude-tool $app "2026-10-16T00:50" SubagentHandback {})
  ]

  let output = (digest-output $dir --to "2026-10-16")
  let first = ($output.days | where date == $DAY | get 0)
  let second = ($output.days | where date == "2026-10-16" | get 0)

  assert equal $first.sessions.0.prompts.0.agent 0.8333
  assert equal $first.sessions.0.prompts.0.repos {app: 0.5, lib: 0.5}
  assert equal $second.sessions.0.prompts.0.agent 0.5
  assert equal $second.sessions.0.continued [
    {from: "2026-10-15 22:00", text: P, agent: 0.6667, repos: {lib: 1.0}}
  ]
}

def "test a local command on a later day leaves no continuation" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lead = "aaaabbbb-0000-4000-8000-000000000005"
  let exported = "<local-command-stdout>Conversation exported</local-command-stdout>"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "22:00" "P")
    (claude-reply $app "22:20" "first")
    (claude-user $app "2026-10-16T10:00" "<command-name>/export</command-name>")
    (claude-user $app "2026-10-16T10:00" $exported)
  ]

  let output = (digest-output $dir --to "2026-10-16")

  assert equal $output.days.1.sessions []
  assert equal $output.days.1.runs []
}

def "test a local command before more conversation leaves no continuation" [] {
  let cases = [
    {command: "/export", prompt: "10:05", reply: "10:30", agent: 0.4167}
    {command: "/model", prompt: "11:00", reply: "11:30", agent: 0.5}
  ]
  for case in $cases {
    let dir = (mktemp --directory)
    let app = (git-repo $dir app)
    let lead = "aaaabbbb-0000-4000-8000-00000000000c"
    transcript $dir [claude projects app $"($lead).jsonl"] [
      (claude-prompt $app "22:00" "P")
      (claude-reply $app "22:20" "first")
      (claude-user $app "2026-10-16T10:00" $"<command-name>($case.command)</command-name>")
      (claude-user $app "2026-10-16T10:00" "<local-command-stdout>done</local-command-stdout>")
      (claude-prompt $app $"2026-10-16T($case.prompt)" "Q")
      (claude-reply $app $"2026-10-16T($case.reply)" "second")
    ]

    let output = (digest-output $dir --to "2026-10-16")

    assert equal $output.days.1.sessions.0.continued [] $"($case.command) leaves no continuation"
    assert equal $output.days.1.sessions.0.prompts.0.agent $case.agent $"Q at ($case.prompt)"
    assert equal $output.days.1.runs [] $"($case.command) leaves no run"
  }
}

def "test a continuation-only day lists the lead session without prompts" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  let lead = "aaaabbbb-0000-4000-8000-000000000004"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "22:00" "P")
    (claude-reply $app "22:20" "first")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "2026-10-16T00:10" "continue" {isSidechain: true})
    (claude-tool $app "2026-10-16T00:40" Write {file_path: ($lib | path join y.nu), content: y})
    (claude-tool $app "2026-10-16T00:50" SubagentHandback {})
  ]

  let output = (digest-output $dir --from "2026-10-16" --to "2026-10-16")

  assert equal ($output.days.0.sessions | length) 1
  assert equal $output.days.0.sessions.0.session $lead
  assert equal $output.days.0.sessions.0.prompts []
  assert equal $output.days.0.sessions.0.replies []
  assert equal $output.days.0.sessions.0.continued [
    {from: "2026-10-15 22:00", text: P, agent: 0.6667, repos: {lib: 1.0}}
  ]
  assert equal ($output.repositories | columns | sort) [app lib]
}

def "test a continuation that wrote nothing takes the prompt repositories" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lead = "aaaabbbb-0000-4000-8000-000000000007"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "22:00" "P")
    (claude-reply $app "22:20" "first")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "22:30" "task" {isSidechain: true})
    (claude-tool $app "23:00" Write {file_path: ($app | path join src x.nu), content: x})
    (claude-tool $app "23:00" SubagentHandback {})
    (claude-user $app "2026-10-16T00:10" "continue" {isSidechain: true})
    (claude-reply $app "2026-10-16T00:40" "done")
  ]

  let output = (digest-output $dir --to "2026-10-16")

  assert equal $output.days.1.sessions.0.continued [
    {from: "2026-10-15 22:00", text: P, agent: 0.5, repos: {app: 1.0}}
  ]
}

def "test a continuation books its turn on the local day" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lead = "aaaabbbb-0000-4000-8000-000000000008"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "10:00" "P")
    (claude-reply $app "10:30" "first")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "2026-10-15T16:30" "continue" {isSidechain: true})
    (claude-tool $app "2026-10-15T17:00" SubagentHandback {})
  ]

  let output = (digest-output $dir --to "2026-10-16" --tz "CST-8")

  assert equal $output.days.0.sessions.0.prompts.0.agent 0.5
  assert equal $output.days.1.sessions.0.continued [
    {from: "2026-10-15 18:00", text: P, agent: 0.5, repos: {}}
  ]
}

def "test a continuation text is excerpted" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lead = "aaaabbbb-0000-4000-8000-00000000000e"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "22:00" "a long prompt")
    (claude-reply $app "22:20" "first")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "2026-10-16T00:10" "continue" {isSidechain: true})
    (claude-tool $app "2026-10-16T00:50" SubagentHandback {})
  ]

  let output = (digest-output $dir --to "2026-10-16" --excerpt-chars 6)

  assert equal ($output.days.1.sessions.0.continued | get text) ["a long..."]
}

def "test turns no prompt started become runs" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lib = (git-repo $dir lib)
  let worker = ($app | path join ".claude" worktrees workmux fix)
  let lead = "aaaabbbb-0000-4000-8000-000000000002"
  transcript $dir [claude projects app team.jsonl] [
    (claude-user $app "10:00" 'relay' {teamName: t, agentName: fix})
    ...(claude-active $app ["10:15"])
    (claude-reply $app "10:30")
  ]
  claude-subagent $dir app $lead orphan {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "10:10" "task" {isSidechain: true})
    ...(claude-active $app ["10:25"])
    (claude-reply $app "10:40")
  ]
  transcript $dir [claude projects lib headless.jsonl] [
    (claude-user $lib "10:20" "Reply with exactly: OK" {entrypoint: sdk-cli})
    (claude-reply $lib "10:30")
  ]
  codex-transcript $dir {id: exec, cwd: $lib, thread_source: user, source: exec} (
    codex-turn "10:40" "probe" --done "10:50"
  )
  codex-transcript $dir {id: sub, cwd: $lib, thread_source: subagent} (
    codex-turn "11:00" "review" --done "11:10"
  )
  transcript $dir [claude projects workmux w.jsonl] [
    (claude-prompt $worker "11:20" "# Task: fix it")
    (claude-reply $worker "11:40")
  ]
  codex-transcript $dir {id: resumed, cwd: $lib, thread_source: user, source: exec} (
    ((codex-turn "12:00" --done "12:05") ++ [(codex-model "12:02")])
    ++ (codex-turn "12:10" "second" --done "12:20")
  )

  let cases = [
    {tool: claude, repo: app, agent: 0.5, text: relay}
    {tool: claude, repo: app, agent: 0.5, text: task}
    {tool: claude, repo: lib, agent: 0.1667, text: "Reply with exactly: OK"}
    {tool: codex, repo: lib, agent: 0.1664, text: probe}
    {tool: codex, repo: lib, agent: 0.1664, text: review}
    {tool: claude, repo: app, agent: 0.3333, text: "# Task: fix it"}
    {tool: codex, repo: lib, agent: 0.2497, text: second}
  ]

  let day = (digest-day $dir)

  assert equal $day.sessions []
  assert equal ($day.runs | select tool repo agent text) $cases
}

def "test agent time belongs to the day its turn started" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "2026-10-14T23:30")
    ...(claude-active /work/app ["2026-10-14T23:45" "2026-10-15T00:15"])
    (claude-reply /work/app "00:30")
    (claude-notification /work/app "23:00")
    ...(claude-active /work/app [
      "23:20" "23:40" "2026-10-16T00:00" "2026-10-16T00:20" "2026-10-16T00:40"
    ])
    (claude-reply /work/app "2026-10-16T01:00")
  ]

  let day = (digest-day $dir)

  assert equal $day.runs.0.agent 2.0
}

def "test sessions report their repository, and the digest lists labels and repository paths" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let cfg = (git-repo $dir nixos-config)
  mkdir ($app | path join src)
  mkdir ($dir | path join scratch)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt $app "10:00" "ship")
    (claude-tool $app "10:01" Write {file_path: ($app | path join src a.nu), content: x})
  ]
  transcript $dir [claude projects cfg b.jsonl] [
    (claude-prompt $cfg "11:00" "tidy")
    (claude-tool $cfg "11:01" Write {file_path: ($cfg | path join README.md), content: x})
  ]
  transcript $dir [claude projects scratch c.jsonl] [
    (claude-prompt ($dir | path join scratch) "12:00" "file")
  ]

  let output = (digest-output $dir)
  let day = $output.days.0

  assert equal ($output | reject days) {
    labels: {default: [work], projects: {nixos-config: [personal]}}
    repositories: {app: $app, "nixos-config": $cfg}
  }
  assert equal ($day.sessions | select repo cwd) [
    {repo: app, cwd: $app}
    {repo: nixos-config, cwd: $cfg}
    {repo: null, cwd: ($dir | path join scratch)}
  ]
  assert equal ($day.sessions.0 | columns) [tool session cwd repo prompts replies continued]
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

  assert equal $day.sessions.0.replies [{at: "10:30", text: done}]
  assert equal ($day.sessions.0.prompts | select at text) [
    {at: "10:00", text: start}
    {at: "10:05", text: "also check tests"}
  ]
  assert equal ($day.sessions.0.prompts | get hours) [0.0833 0.5833]
  assert equal ($day.sessions.0.prompts | get agent) [0.0833 0.4167]
}

def "test a reply-less turn ends at its last model record" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "P")
    ...(claude-active /work/app ["10:10" "10:20"])
    (claude-prompt /work/app "10:25" "Q")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions.0.prompts | select at agent) [
    {at: "10:00", agent: 0.3333}
    {at: "10:25", agent: 0}
  ]
}

def "test a compaction belongs to the turn it compacted" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "P")
    ...(claude-active /work/app ["10:05"])
    (claude-user /work/app "10:10" "summary" {isCompactSummary: true})
  ]
  transcript $dir [claude projects app b.jsonl] [
    (claude-prompt /work/app "10:00" "P")
    ...(claude-active /work/app ["10:05"])
    (claude-user /work/app "10:10" "summary" {isCompactSummary: true})
    (claude-reply /work/app "10:20" "done")
  ]
  codex-transcript $dir {id: c, cwd: /work/app, thread_source: user} [
    ...(codex-turn "10:00" "P")
    (codex-model "10:05")
    {type: response_item, timestamp: (at "10:10"), payload: {type: compaction}}
  ]

  let day = (digest-day $dir)

  assert equal (
    $day.sessions
    | select session prompts
    | each {|s| {session: $s.session, agent: $s.prompts.0.agent} }
    | sort-by session
  ) [
    {session: a, agent: 0.1667}
    {session: b, agent: 0.3333}
    {session: c, agent: 0.1664}
  ]
  assert equal $day.runs []
}

def "test a turn with no model output earns nothing" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "P")
    (claude-prompt /work/app "10:05" "Q")
  ]

  let day = (digest-day $dir)

  assert equal ($day.sessions.0.prompts | select at agent) [
    {at: "10:00", agent: 0}
    {at: "10:05", agent: 0}
  ]
}

def "test an agent turn earns at most the cap" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    ...(claude-active /work/app ["10:20" "10:40" "11:00" "11:20" "11:40" "12:00" "12:20" "12:40"])
    (claude-reply /work/app "13:00")
  ]

  let day = (digest-day $dir {agentMaxMinutes: 90})

  assert equal $day.runs.0.agent 1.5
}

def "test a stalled delegate earns only the time before its gap" [] {
  let dir = (mktemp --directory)
  let app = (git-repo $dir app)
  let lead = "aaaabbbb-0000-4000-8000-000000000009"
  transcript $dir [claude projects app $"($lead).jsonl"] [
    (claude-prompt $app "09:55" "P")
    (claude-reply $app "10:00" "first")
  ]
  claude-subagent $dir app $lead a {agentType: implementer, toolUseId: t, spawnDepth: 1} [
    (claude-user $app "10:05" "task" {isSidechain: true})
    ...(claude-active $app ["10:25" "10:45"])
    (claude-tool $app "13:45" SubagentHandback {})
  ]

  let day = (digest-day $dir)

  assert equal $day.sessions.0.prompts.0.agent 0.75
}

def "test a gap of exactly the idle threshold keeps the turn span" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    ...(claude-active /work/app ["10:30"])
    (claude-reply /work/app "11:00")
  ]

  let day = (digest-day $dir)

  assert equal $day.runs.0.agent 1
}

def "test a turn ends at its first long gap" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    ...(claude-active /work/app ["10:10" "10:50" "11:00" "12:00"])
    (claude-reply /work/app "12:05")
  ]

  let day = (digest-day $dir)

  assert equal $day.runs.0.agent 0.1667
}

def "test a later turn gap does not cut an earlier turn" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-notification /work/app "10:00")
    ...(claude-active /work/app ["10:05"])
    (claude-notification /work/app "10:10")
    ...(claude-active /work/app ["10:15" "10:20"])
    (claude-reply /work/app "11:30")
  ]

  let day = (digest-day $dir)

  assert equal $day.runs.0.agent 0.3333
}

def "test each tool turn ends at its last record before a long gap" [] {
  let dir = (mktemp --directory)
  let item = {type: UserMessage, content: [{type: text, text: "go"}]}
  codex-transcript $dir {id: codex, cwd: /work/app, thread_source: user, source: exec} [
    (codex-event "10:00" {type: task_started, turn_id: t})
    (codex-event "10:00" {type: item_completed, item: $item, turn_id: t})
    (codex-event "10:20" {type: token_count})
    (codex-event "11:30" {type: task_complete, last_agent_message: ok})
  ]
  transcript $dir [omp sessions app a.jsonl] [
    {type: session, id: omp, cwd: /work/app}
    (omp-user "12:00" "go" --agent)
    (omp-tool "12:20" [{type: toolCall, id: r, name: read, arguments: {path: x}}])
    (omp-reply "13:30")
  ]

  let day = (digest-day $dir)

  assert equal ($day.runs | select tool agent) [
    {tool: codex, agent: 0.3333}
    {tool: omp, agent: 0.3333}
  ]
}

def "test canceled Codex turns cannot borrow a later reply" [] {
  let dir = (mktemp --directory)
  let prompt = {type: UserMessage, content: [{type: text, text: "start"}]}
  codex-transcript $dir {id: canceled, cwd: /work/app, thread_source: user} [
    (codex-event "10:00" {type: task_started, turn_id: first})
    (codex-event "10:00" {type: item_completed, item: $prompt, turn_id: first})
    (codex-event "10:01" {type: turn_aborted, turn_id: first})
    (codex-event "13:00" {type: task_started, turn_id: second})
    (codex-model "13:05")
    (codex-event "13:10" {type: task_complete, last_agent_message: done})
    (codex-event "13:11" {type: turn_aborted, turn_id: second})
    (codex-event "13:12" {type: task_complete, last_agent_message: final})
  ]

  let day = (digest-day $dir)

  assert equal $day.sessions.0.prompts.0.hours 0.1667
  assert equal $day.sessions.0.prompts.0.agent 0.1667
  assert equal $day.sessions.0.replies [{at: "13:12", text: final}]
}

def "test a day keeps its final replies past midnight until the next prompt" [] {
  let dir = (mktemp --directory)
  transcript $dir [claude projects app a.jsonl] [
    (claude-prompt /work/app "10:00" "start")
    (claude-reply /work/app "10:05" "working")
    (claude-tool /work/app "10:06" Edit {
      file_path: /work/app/a.nu
      old_string: a
      new_string: b
      replace_all: false
    })
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
