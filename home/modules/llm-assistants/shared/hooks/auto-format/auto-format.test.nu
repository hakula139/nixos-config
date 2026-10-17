#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const STUB = ($SCRIPT_DIR | path join cspell.stub.nu)

def install-stub [target: string] {
  mkdir ($target | path dirname)
  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $STUB) | save $target
  ^chmod +x $target
}

def init-repo []: nothing -> string {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  $repo
}

def write-notes [path: string]: nothing -> string {
  mkdir ($path | path dirname)
  "# Notes\n" | save $path
  $path
}

# Runs the hook on a Markdown write from `cwd` and returns the cspell calls it made, with the path of
# the pinned cspell stub. The other Markdown tools are a no-op executable.
def spell-check [path: string, cwd: string]: nothing -> record {
  let dir = (mktemp --directory | path expand)
  let cspell = ($dir | path join cspell)
  let noop = ($dir | path join noop)
  let config_file = ($dir | path join config.json)
  let log = ($dir | path join calls.jsonl)

  install-stub $cspell
  "#!/bin/sh\n" | save $noop
  ^chmod +x $noop
  {
    cspell: $cspell
    direnv: ""
    dprint: $noop
    dprintConfig: ""
    git: (which git | get 0.path)
    markdownlint: $noop
    patchInput: ""
  }
  | to json
  | save $config_file

  let run = with-env {STUB_LOG: $log} {
    {tool_name: Write, tool_input: {file_path: $path}, cwd: $cwd}
    | to json
    | ^$nu.current-exe --no-config-file $SCRIPT $config_file
    | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  let calls = if ($log | path exists) { open $log | lines | each { from json } } else { [] }
  {pinned: $cspell, calls: $calls, output: ($run.stdout | str trim)}
}

def "test cspell runs from the edited file repository with its root as gitignore root" [] {
  let repo = (init-repo)
  let file = (write-notes ($repo | path join docs notes.md))

  let result = (spell-check $file (mktemp --directory))

  assert equal $result.calls [
    {bin: $result.pinned, cwd: $repo, args: ["--no-progress" "--gitignore-root" $repo $file]}
  ]
}

def "test cspell outside a repository runs from the session directory" [] {
  let file = (write-notes (mktemp --directory | path expand | path join notes.md))
  let session = (mktemp --directory | path expand)

  let result = (spell-check $file $session)

  assert equal $result.calls [{bin: $result.pinned, cwd: $session, args: ["--no-progress" $file]}]
}

def "test a project cspell takes precedence over the pinned one" [] {
  let repo = (init-repo)
  let project = ($repo | path join node_modules .bin cspell)
  install-stub $project
  let file = (write-notes ($repo | path join docs notes.md))

  let result = (spell-check $file $repo)

  assert equal ($result.calls | get bin) [$project]
}

def "test a file the repository ignores is not spell checked" [] {
  let repo = (init-repo)
  ".agents/plans\n" | save ($repo | path join .gitignore)
  let file = (write-notes ($repo | path join .agents plans notes.md))

  let result = (spell-check $file $repo)

  assert equal $result.calls []
  assert equal $result.output ""
}
