#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const PATCH_INPUT = ($SCRIPT_DIR | path join .. lib patch-input patch-input.nu)
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

# Only tool stubs, `cat`, and the `--path` directories are available to the hook.
def run-event [
  input: record
  --path: list<string> = []
  --fail: string = ""
  --direnv
  --export: record = {}
]: nothing -> record {
  let dir = (mktemp --directory | path expand)
  let bin = ($dir | path join bin)
  let log = ($dir | path join calls.jsonl)
  let config_file = ($dir | path join config.json)
  let parser = ($bin | path join patch-input)

  mkdir $bin
  ^ln -s (which cat | get 0.path) ($bin | path join cat)
  open --raw $PATCH_INPUT
  | str replace --regex '^#!.*' $"#!($nu.current-exe) --no-config-file"
  | save $parser
  ^chmod +x $parser
  let base = {
    direnv: (if $direnv { install-stub ($bin | path join direnv) } else { "" })
    dprintConfig: ""
    git: (which git | get 0.path)
    markdownlintConfig: ""
    patchInput: $parser
  }
  $TOOLS
  | reduce --fold $base {|tool, config|
    $config | insert $tool (install-stub ($bin | path join $tool))
  }
  | to json
  | save $config_file

  let run = with-env {
    STUB_LOG: $log
    STUB_FAIL: $fail
    STUB_EXPORT: ($export | to json --raw)
    PATH: ([$bin ...$path] | str join ":")
  } {
    $input
    | to json
    | ^$nu.current-exe --no-config-file $SCRIPT $config_file
    | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  {
    bin: $bin
    calls: (if ($log | path exists) { open $log | from json --objects } else { [] })
    run: $run
  }
}

def run-hook [file: string, cwd: string, --path: list<string> = []]: nothing -> list<record> {
  let input = {tool_name: Write, tool_input: {file_path: $file}, cwd: $cwd}
  (run-event $input --path $path).calls
}

def patch-event [files: list<record>, cwd: string]: nothing -> record {
  let headers = ($files | each {|file| $"*** ($file.action) File: ($file.path)" })
  {
    tool_name: apply_patch
    tool_input: {command: (["*** Begin Patch" ...$headers "*** End Patch"] | str join "\n")}
    cwd: $cwd
  }
}

def cargo-calls [cargo: string, root: string]: nothing -> list<record> {
  [
    {bin: $cargo, cwd: $root, args: ["fmt" "--all" "--quiet"]}
    {bin: $cargo, cwd: $root, args: ["clippy" "--all-targets" "--quiet" "--" "-D" "warnings"]}
  ]
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

def "test mixed patches run cargo once per root and retain file tools" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  let tools = ($repo | path join tools)
  let cargo = (install-stub ($tools | path join cargo))
  write-file ($repo | path join a.rs)
  let nix = (write-file ($repo | path join b.nix))
  write-file ($repo | path join c.rs)
  let shell = (write-file ($repo | path join d.sh))
  write-file ($repo | path join deleted.nix)
  mkdir ($repo | path join directory.nix)
  let event = (patch-event [
    {action: Update, path: c.rs}
    {action: Update, path: a.rs}
    {action: Update, path: b.nix}
    {action: Update, path: ./a.rs}
    {action: Update, path: ./b.nix}
    {action: Add, path: d.sh}
    {action: Delete, path: deleted.nix}
    {action: Update, path: missing.nix}
    {action: Update, path: directory.nix}
  ] $repo)

  let result = (run-event $event --path [$tools])

  let bin = $result.bin
  let expected = (cargo-calls $cargo $repo | append [
    {bin: ($bin | path join nixfmt), cwd: $repo, args: [$nix]}
    {bin: ($bin | path join shfmt), cwd: $repo, args: ["-w" $shell]}
    {bin: ($bin | path join shellcheck), cwd: $repo, args: ["--format" "gcc" $shell]}
  ])
  assert equal $result.calls $expected
  assert equal $result.run.stdout ""
}

def "test rust roots stay distinct across repositories and linked worktrees" [] {
  let dir = (mktemp --directory | path expand)
  let repo = ($dir | path join a-repo)
  let other = ($dir | path join b-repo)
  mkdir $repo $other
  ^git -C $repo init --quiet
  ^git -C $other init --quiet
  ^git -C $repo -c user.name=test -c user.email=test@test commit --quiet --allow-empty -m init
  let worktree = ($repo | path join .claude worktrees wt)
  ^git -C $repo worktree add --quiet --detach $worktree
  let cargo = (install-stub ($dir | path join tools cargo))
  let files = ([
    ($repo | path join a.rs)
    ($repo | path join z.rs)
    ($worktree | path join a.rs)
    ($worktree | path join z.rs)
    ($other | path join a.rs)
    ($other | path join z.rs)
  ] | each {|path| {action: Update, path: (write-file $path)} })

  let result = (run-event (patch-event $files $dir) --path [($cargo | path dirname)])

  let expected = (
    cargo-calls $cargo $worktree
    | append (cargo-calls $cargo $repo)
    | append (cargo-calls $cargo $other)
  )
  assert equal $result.calls $expected
}

def "test rust roots outside git keep their directory fallback" [] {
  let dir = (mktemp --directory | path expand)
  let cargo = (install-stub ($dir | path join tools cargo))
  let first = ($dir | path join a)
  let second = ($dir | path join b)
  let files = ([
    ($first | path join a.rs)
    ($first | path join z.rs)
    ($second | path join a.rs)
    ($second | path join z.rs)
  ] | each {|path| {action: Add, path: (write-file $path)} })

  let result = (run-event (patch-event $files $dir) --path [($cargo | path dirname)])

  let expected = (cargo-calls $cargo $first | append (cargo-calls $cargo $second))
  assert equal $result.calls $expected
}

def "test missing cargo leaves file checks running" [] {
  let dir = (mktemp --directory | path expand)
  let rust = (write-file ($dir | path join a.rs))
  let nix = (write-file ($dir | path join b.nix))
  let event = (patch-event [{action: Update, path: $rust} {action: Update, path: $nix}] $dir)

  let result = (run-event $event)

  let nixfmt = ($result.bin | path join nixfmt)
  assert equal $result.calls [{bin: $nixfmt, cwd: $dir, args: [$nix]}]
  assert equal $result.run.stdout ""
}

def "test cargo failures report once per root and continue all checks" [] {
  let dir = (mktemp --directory | path expand)
  let cargo = (install-stub ($dir | path join tools cargo))
  let first = ($dir | path join a)
  let second = ($dir | path join b)
  let files = ([
    ($first | path join a.rs)
    ($first | path join z.rs)
    ($second | path join a.rs)
  ] | each {|path| {action: Update, path: (write-file $path)} })

  let result = (run-event (patch-event $files $dir) --path [($cargo | path dirname)] --fail "cargo fmt --all --quiet")

  let expected = (cargo-calls $cargo $first | append (cargo-calls $cargo $second))
  assert equal $result.calls $expected
  let reports = [
    "Formatters and linters reported problems in the edited files."
    $"cargo exited with 7 on ($first | path join a.rs):\nstub failure"
    $"cargo exited with 7 on ($second | path join a.rs):\nstub failure"
  ]
  assert equal ($result.run.stdout | from json) {
    hookSpecificOutput: {
      hookEventName: PostToolUse
      additionalContext: ($reports | str join "\n\n")
    }
  }
}

def "test project environment loads once from event cwd before checks" [] {
  let dir = (mktemp --directory | path expand)
  let repo = ($dir | path join repo)
  mkdir $repo
  ^git -C $repo init --quiet
  let cargo = (install-stub ($dir | path join tools cargo))
  let file = (write-file ($repo | path join src lib.rs))
  let input = {tool_name: Write, tool_input: {file_path: $file}, cwd: $dir}

  let result = (run-event $input --direnv --export {PATH: ($cargo | path dirname), STUB_FAIL: null} --fail "cargo fmt --all --quiet")

  let direnv = ($result.bin | path join direnv)
  let expected = ([{bin: $direnv, cwd: $dir, args: [export json]}] | append (cargo-calls $cargo $repo))
  assert equal $result.calls $expected
  assert equal $result.run.stdout ""
}

def "test failed environment loading stops checks" [] {
  let dir = (mktemp --directory | path expand)
  let file = (write-file ($dir | path join file.nix))
  let input = {tool_name: Write, tool_input: {file_path: $file}, cwd: $dir}

  let result = (run-event $input --direnv --fail "direnv export json")

  let direnv = ($result.bin | path join direnv)
  assert equal $result.calls [{bin: $direnv, cwd: $dir, args: [export json]}]
  assert equal $result.run.stdout ""
  assert equal ($result.run.stderr | str trim) "stub failure"
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
