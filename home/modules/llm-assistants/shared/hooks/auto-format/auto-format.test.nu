#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const STUB = ($SCRIPT_DIR | path join cspell.stub.nu)

# Runs the hook on a Markdown write from `cwd` and returns the cspell calls it made. The other
# Markdown tools are a no-op executable.
def spell-check [path: string, cwd: string]: nothing -> list<record> {
  let dir = (mktemp --directory)
  let cspell = ($dir | path join cspell)
  let noop = ($dir | path join noop)
  let config_file = ($dir | path join config.json)
  let log = ($dir | path join calls.jsonl)

  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $STUB) | save $cspell
  "#!/bin/sh\n" | save $noop
  ^chmod +x $cspell $noop
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

  open $log | lines | each { from json }
}

def "test cspell runs from the edited file repository with its root as gitignore root" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  mkdir ($repo | path join docs)
  let file = ($repo | path join docs notes.md)
  "# Notes\n" | save $file

  let calls = (spell-check $file (mktemp --directory))

  assert equal $calls [{cwd: $repo, args: ["--no-progress" "--gitignore-root" $repo $file]}]
}

def "test cspell outside a repository runs from the session directory" [] {
  let file = (mktemp --directory | path expand | path join notes.md)
  "# Notes\n" | save $file
  let session = (mktemp --directory | path expand)

  let calls = (spell-check $file $session)

  assert equal $calls [{cwd: $session, args: ["--no-progress" $file]}]
}
