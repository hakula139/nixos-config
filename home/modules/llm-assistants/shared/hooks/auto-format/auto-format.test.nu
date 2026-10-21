#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const TOOLS = [
  cspell
  dprint
  markdownlint
  nixfmt
  nuCheck
  prettier
  pyright
  ruff
  shellcheck
  shfmt
  taplo
]

# Copies the tool stub to `target` and returns `target`, the path the stub logs as its `bin`.
def install-stub [target: string]: nothing -> string {
  mkdir ($target | path dirname)
  cp ($env.NU_TEST_STUBS | path join tool) $target
  $target
}

# Runs the hook on a Write of `file` from `cwd`, with a stub for every configured tool and the
# `--path` directories as the only other `PATH` entries besides `cat`. Returns the stub calls in
# order, each with its `bin` path, `cwd`, and `args`.
def run-hook [file: string, cwd: string, --path: list<string> = []]: nothing -> list<record> {
  let dir = (mktemp --directory | path expand)
  let bin = ($dir | path join bin)
  let log = ($dir | path join calls.jsonl)
  let config_file = ($dir | path join config.json)

  mkdir $bin
  ^ln -s (which cat | get 0.path) ($bin | path join cat)
  let base = {
    direnv: ""
    dprintConfig: ""
    git: (which git | get 0.path)
    markdownlintConfig: ""
    patchInput: ""
  }
  $TOOLS
  | reduce --fold $base {|tool, config|
    $config | insert $tool (install-stub ($bin | path join $tool))
  }
  | to json
  | save $config_file

  let run = with-env {STUB_LOG: $log, PATH: ([$bin ...$path] | str join ":")} {
    {tool_name: Write, tool_input: {file_path: $file}, cwd: $cwd}
    | to json
    | ^$nu.current-exe --no-config-file $SCRIPT $config_file
    | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  if ($log | path exists) { open $log | from json --objects } else { [] }
}

# Writes a file at `path`, creating its parent directories, and returns `path`.
def write-file [path: string]: nothing -> string {
  mkdir ($path | path dirname)
  "content\n" | save $path
  $path
}

def "test each extension runs its tools with their flags" [] {
  let cases = [
    {ext: sh, tools: [], calls: [[shfmt ["-w"]] [shellcheck ["--format" "gcc"]]]}
    {ext: nix, tools: [], calls: [[nixfmt []]]}
    {ext: nu, tools: [], calls: [[nuCheck []]]}
    {
      ext: py
      tools: []
      calls: [
        [ruff ["format"]]
        [ruff ["check" "--fix" "--output-format" "concise"]]
        [pyright ["--warnings"]]
      ]
    }
    {
      ext: rs
      tools: [cargo]
      calls: [
        [cargo ["fmt" "--all" "--quiet"] false]
        [cargo ["clippy" "--all-targets" "--quiet" "--" "-D" "warnings"] false]
      ]
    }
    {ext: go, tools: [goimports gofmt], calls: [[goimports ["-w"]]]}
    {ext: go, tools: [gofmt], calls: [[gofmt ["-w"]]]}
    {ext: toml, tools: [], calls: [[taplo ["fmt"]]]}
    {ext: ts, tools: [], calls: [[prettier ["--log-level" "warn" "--write"]]]}
    {
      ext: md
      tools: []
      calls: [
        [dprint ["fmt" "--config" "" "--stdin" "md"] false]
        [markdownlint ["--config" "" "--fix"]]
        [cspell ["--no-progress" "--no-must-find-files"]]
      ]
    }
    {ext: txt, tools: [], calls: []}
  ]

  for case in $cases {
    let dir = (mktemp --directory | path expand)
    let tools = ($dir | path join tools)
    mkdir $tools
    $case.tools | each {|tool| install-stub ($tools | path join $tool) }
    let file = (write-file ($dir | path join $"file.($case.ext)"))

    let calls = (run-hook $file $dir --path [$tools])

    let expected = (
      $case.calls
      | each {|call|
        let takes_path = ($call | get --optional 2 | default true)
        {bin: $call.0, args: (if $takes_path { [...$call.1 $file] } else { $call.1 })}
      }
    )
    let actual = ($calls | each {|call| {bin: ($call.bin | path basename), args: $call.args} })
    assert equal $actual $expected $"extension ($case.ext) with ($case.tools)"
  }
}

def "test tools run from the repository root of the edited file" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  let tools = ($repo | path join tools)
  install-stub ($tools | path join cargo)
  let file = (write-file ($repo | path join crate src lib.rs))

  let calls = (run-hook $file (mktemp --directory) --path [$tools])

  assert equal ($calls | get cwd) [$repo $repo]
}

def "test tools outside a repository run from the directory of the edited file" [] {
  let dir = (mktemp --directory | path expand)
  let file = (write-file ($dir | path join docs notes.md))

  let calls = (run-hook $file (mktemp --directory))

  let docs = ($dir | path join docs)
  assert equal ($calls | get cwd) [$docs $docs $docs]
}

def "test tools in a linked worktree run from the worktree root" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  ^git -C $repo -c user.name=test -c user.email=test@test commit --quiet --allow-empty -m init
  let worktree = ($repo | path join .claude worktrees wt)
  ^git -C $repo worktree add --quiet --detach $worktree
  let file = (write-file ($worktree | path join docs notes.md))

  let calls = (run-hook $file $repo)

  assert equal ($calls | get cwd) [$worktree $worktree $worktree]
}

def "test the nearest project cspell takes precedence" [] {
  let dir = (mktemp --directory | path expand)
  install-stub ($dir | path join node_modules .bin cspell)
  let nearest = (install-stub ($dir | path join docs node_modules .bin cspell))
  let file = (write-file ($dir | path join docs notes.md))

  let calls = (run-hook $file $dir)

  assert equal ($calls | where ($it.bin | path basename) == cspell | get bin) [$nearest]
}

def "test malformed input exits cleanly without output" [] {
  for input in ["not json" ({tool_name: Write, tool_input: {}, cwd: "/"} | to json)] {
    let config_file = (mktemp --directory | path join config.json)
    {direnv: ""} | to json | save $config_file

    let run = ($input | ^$nu.current-exe --no-config-file $SCRIPT $config_file | complete)

    assert equal [$run.exit_code $run.stdout] [0 ""] $input
  }
}
