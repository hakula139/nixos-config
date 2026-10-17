#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const STUB = ($SCRIPT_DIR | path join tool.stub.nu)
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

# Runs the hook on `payload` with a stub for every configured tool, `overrides` merged over that
# config, and `path` as the only `PATH` entries besides `cat`. Returns the stub `calls` in order,
# with each `bin` reduced to its file name unless it lives outside the stub directory, and the
# hook's `stdout`.
def run-hook [
  payload: any
  overrides: record = {}
  --path: list<string> = []
  --vars: record = {}
]: nothing -> record {
  let dir = (mktemp --directory | path expand)
  let bin = ($dir | path join bin)
  let log = ($dir | path join calls.jsonl)
  let config_file = ($dir | path join config.json)

  mkdir $bin
  ^ln -s (which cat | get 0.path) ($bin | path join cat)
  $TOOLS
  | reduce --fold {} {|tool, config|
    $config | insert $tool (install-stub ($bin | path join $tool))
  }
  | merge {direnv: "", dprintConfig: "", git: (which git | get 0.path), patchInput: ""}
  | merge $overrides
  | to json
  | save $config_file

  let input = if ($payload | describe | str starts-with "string") { $payload } else {
    $payload | to json
  }
  let run = with-env ({STUB_LOG: $log, PATH: ([$bin ...$path] | str join ":")} | merge $vars) {
    $input | ^$nu.current-exe --no-config-file $SCRIPT $config_file | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  let calls = if ($log | path exists) { open $log | lines | each { from json } } else { [] }
  {
    calls: (
      $calls
      | update bin {|call|
        if ($call.bin | path dirname) == $bin { $call.bin | path basename } else { $call.bin }
      }
    )
    stdout: $run.stdout
  }
}

def install-stub [target: string]: nothing -> string {
  mkdir ($target | path dirname)
  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $STUB) | save $target
  ^chmod +x $target
  $target
}

def write-payload [path: string, cwd: string]: nothing -> record {
  {tool_name: Write, tool_input: {file_path: $path}, cwd: $cwd}
}

def init-repo []: nothing -> string {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  $repo
}

def write-file [path: string]: nothing -> string {
  mkdir ($path | path dirname)
  "content\n" | save $path
  $path
}

def calls-to [calls: list<record>, tool: string]: nothing -> list<record> {
  $calls | where {|call| ($call.bin | path basename) == $tool }
}

def "test cspell runs from the repository of the edited file" [] {
  let repo = (init-repo)
  let file = (write-file ($repo | path join docs notes.md))

  let result = (run-hook (write-payload $file (mktemp --directory)))

  assert equal (calls-to $result.calls cspell | select bin cwd args) [
    {
      bin: cspell
      cwd: $repo
      args: ["--no-progress" "--no-must-find-files" "--gitignore-root" $repo $file]
    }
  ]
}

def "test cspell outside a repository runs from the directory of the edited file" [] {
  let dir = (mktemp --directory | path expand)
  let file = (write-file ($dir | path join notes.md))

  let result = (run-hook (write-payload $file (mktemp --directory)))

  assert equal (calls-to $result.calls cspell | select cwd args) [
    {cwd: $dir, args: ["--no-progress" "--no-must-find-files" $file]}
  ]
}

def "test cspell in a linked worktree runs from the worktree" [] {
  let repo = (init-repo)
  ".claude/worktrees\n" | save ($repo | path join .gitignore)
  ^git -C $repo add .gitignore
  ^git -C $repo -c user.name=test -c user.email=test@example.com commit --quiet -m init
  let worktree = ($repo | path join .claude worktrees wt)
  ^git -C $repo worktree add --quiet --detach $worktree
  let file = (write-file ($worktree | path join docs notes.md))

  let result = (run-hook (write-payload $file $repo))

  assert equal (calls-to $result.calls cspell | select cwd args) [
    {
      cwd: $worktree
      args: ["--no-progress" "--no-must-find-files" "--gitignore-root" $worktree $file]
    }
  ]
}

def "test the nearest project cspell takes precedence" [] {
  let repo = (init-repo)
  install-stub ($repo | path join node_modules .bin cspell)
  let nearest = (install-stub ($repo | path join docs node_modules .bin cspell))
  let file = (write-file ($repo | path join docs notes.md))

  let result = (run-hook (write-payload $file $repo))

  assert equal (calls-to $result.calls cspell | get bin) [$nearest]
}

def "test a failing tool is reported with its name and the first ten lines" [] {
  let dir = (mktemp --directory | path expand)
  let store_hash = (1..32 | each { "a" } | str join)
  let nu_check = (install-stub ($dir | path join $"($store_hash)-nu-check"))
  let file = (write-file ($dir | path join script.nu))
  let output = (1..12 | each { $"line ($in)" } | str join "\n")

  let result = (
    run-hook (write-payload $file $dir) {nuCheck: $nu_check} --vars {
      STUB_OUTPUT: $output
      STUB_STATUS: "3"
    }
  )

  let report = ($result.stdout | from json | get hookSpecificOutput)
  assert equal $report.hookEventName PostToolUse
  assert equal $report.additionalContext ([
    "Formatters and linters reported problems in the edited files."
    ""
    $"nu-check exited with 3 on ($file):"
    ...(1..10 | each { $"line ($in)" })
  ] | str join "\n")
}

def "test a crashing markdownlint does not stop cspell" [] {
  let dir = (mktemp --directory | path expand)
  let file = (write-file ($dir | path join notes.md))

  let result = (
    run-hook (write-payload $file $dir) {markdownlint: ($dir | path join missing-markdownlint)}
  )

  assert equal (calls-to $result.calls cspell | length) 1
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
        [markdownlint ["--fix"]]
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

    let result = (run-hook (write-payload $file $dir) --path [$tools])

    let expected = (
      $case.calls
      | each {|call|
        let takes_path = ($call | get --optional 2 | default true)
        {bin: $call.0, args: (if $takes_path { [...$call.1 $file] } else { $call.1 })}
      }
    )
    let actual = (
      $result.calls | each {|call| {bin: ($call.bin | path basename), args: $call.args} }
    )
    assert equal $actual $expected $"extension ($case.ext) with ($case.tools)"
  }
}

def "test a project prettier and eslint replace the pinned formatter" [] {
  let dir = (mktemp --directory | path expand)
  let prettier = (install-stub ($dir | path join node_modules .bin prettier))
  let eslint = (install-stub ($dir | path join node_modules .bin eslint))
  let file = (write-file ($dir | path join app.ts))

  let result = (run-hook (write-payload $file $dir))

  assert equal ($result.calls | select bin args) [
    {bin: $prettier, args: ["--log-level" "warn" "--write" $file]}
    {bin: $eslint, args: ["--fix" "--max-warnings" "0" "--no-warn-ignored" $file]}
  ]
}

def "test empty dev tool paths are skipped" [] {
  let dir = (mktemp --directory | path expand)
  let files = ([py toml ts md] | each {|ext| write-file ($dir | path join $"file.($ext)") })
  let empty = {dprint: "", prettier: "", pyright: "", ruff: "", taplo: ""}

  let calls = ($files | each {|file| (run-hook (write-payload $file $dir) $empty).calls } | flatten)

  assert equal $calls []
}

def "test apply_patch formats each changed file once against the payload directory" [] {
  let dir = (mktemp --directory | path expand)
  let patch_input = (install-patch-input $dir)
  [a.nix c.nix d.nix] | each {|name| write-file ($dir | path join $name) }
  let patch = "
    *** Begin Patch
    *** Add File: a.nix
    +{ }
    *** Update File: b.nix
    *** Move to: c.nix
    @@
    +{ }
    *** Delete File: d.nix
    *** Update File: a.nix
    @@
    +{ }
    *** End Patch
    " | str dedent
  let payload = {tool_name: apply_patch, tool_input: {command: $patch}, cwd: $dir}

  let result = (run-hook $payload {patchInput: $patch_input})

  assert equal ($result.calls | select bin args) [
    {bin: nixfmt, args: [($dir | path join a.nix)]}
    {bin: nixfmt, args: [($dir | path join c.nix)]}
  ]
}

def install-patch-input [dir: string]: nothing -> string {
  let target = ($dir | path join patch-input)
  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $PATCH_INPUT) | save $target
  ^chmod +x $target
  $target
}

def "test the direnv environment applies to the tools" [] {
  let dir = (mktemp --directory | path expand)
  let tools = ($dir | path join tools)
  install-stub ($tools | path join cargo)
  let direnv = (install-stub ($dir | path join direnv))
  let file = (write-file ($dir | path join lib.rs))
  let cat_dir = (which cat | get 0.path | path dirname)
  let exported = {PATH: ([$tools $cat_dir] | str join ":"), STALE: null} | to json

  let result = (
    run-hook (write-payload $file $dir) {direnv: $direnv} --vars {
      STALE: "1"
      STUB_OUTPUT: $exported
    }
  )

  assert equal ($result.calls | select bin stale) [
    {bin: $direnv, stale: true}
    {bin: ($tools | path join cargo), stale: false}
    {bin: ($tools | path join cargo), stale: false}
  ]
}

def "test a failing direnv runs nothing and prints nothing" [] {
  let dir = (mktemp --directory | path expand)
  let direnv = (install-stub ($dir | path join direnv))
  let file = (write-file ($dir | path join notes.nix))

  let result = (run-hook (write-payload $file $dir) {direnv: $direnv} --vars {STUB_STATUS: "1"})

  assert equal ($result.calls | get bin) [$direnv]
  assert equal $result.stdout ""
}

def "test malformed input exits cleanly without output" [] {
  let dir = (mktemp --directory | path expand)

  let malformed = (run-hook "not json")
  let missing_path = (run-hook {tool_name: Write, tool_input: {}, cwd: $dir})

  assert equal [$malformed.stdout $missing_path.stdout] ["" ""]
  assert equal [$malformed.calls $missing_path.calls] [[] []]
}

def "test cargo runs from the directory of the edited Rust file" [] {
  let crate = (mktemp --directory | path expand)
  let tools = ($crate | path join tools)
  install-stub ($tools | path join cargo)
  let file = (write-file ($crate | path join src lib.rs))

  let result = (run-hook (write-payload $file (mktemp --directory)) --path [$tools])

  assert equal ($result.calls | get cwd) [($crate | path join src) ($crate | path join src)]
}
