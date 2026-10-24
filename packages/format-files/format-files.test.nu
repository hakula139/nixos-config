#!/usr/bin/env nu

# ==================================================================================================
# File Formatting Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join format-files.nu)
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

# Only tool stubs and the `--path` directories are available to the formatter.
def run-files [
  paths: list<string>
  cwd: string
  --path: list<string> = []
  --checks
  --fail: string = ""
  --direnv
  --export: record = {}
  --exit-code: int = 0
]: nothing -> record {
  let dir = (mktemp --directory | path expand)
  let bin = ($dir | path join bin)
  let log = ($dir | path join calls.jsonl)
  let config_file = ($dir | path join config.json)

  mkdir $bin
  let base = {
    direnv: (if $direnv { install-stub ($bin | path join direnv) } else { "" })
    dprintConfigDir: ""
    git: (which git | get 0.path)
    markdownlintConfig: ""
  }
  $TOOLS
  | reduce --fold $base {|tool, config|
    $config | insert $tool (install-stub ($bin | path join $tool))
  }
  | to json
  | save $config_file

  let args = if $checks { ["--checks" ...$paths] } else { $paths }
  let run = with-env {
    STUB_LOG: $log
    STUB_FAIL: $fail
    STUB_EXPORT: ($export | to json --raw)
    PATH: ([$bin ...$path] | str join ":")
  } {
    cd $cwd
    ^$nu.current-exe --no-config-file $SCRIPT $config_file ...$args | complete
  }
  assert equal $run.exit_code $exit_code $run.stderr

  {
    bin: $bin
    calls: (if ($log | path exists) { open $log | from json --objects } else { [] })
    run: $run
  }
}

def file-calls [file: string, cwd: string, --path: list<string> = []]: nothing -> list<record> {
  (run-files [$file] $cwd --path $path --checks).calls
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
        [dprint ["fmt" "--allow-no-files"]]
        [markdownlint ["--config" "" "--fix"]]
        [cspell ["--no-progress" "--no-must-find-files"]]
      ]
    }
    {ext: txt, tools: [], calls: []}
    {ext: sh, checks: false, tools: [], calls: [[shfmt ["-w"]]]}
    {ext: nu, checks: false, tools: [], calls: []}
    {ext: py, checks: false, tools: [], calls: [[ruff ["format"]]]}
    {ext: rs, checks: false, tools: [cargo], calls: [[cargo ["fmt" "--all" "--quiet"] false]]}
    {
      ext: md
      checks: false
      tools: []
      calls: [[dprint ["fmt" "--allow-no-files"]]]
    }
  ]

  for case in $cases {
    let dir = (mktemp --directory | path expand)
    let tools = ($dir | path join tools)
    mkdir $tools
    $case.tools | each {|tool| install-stub ($tools | path join $tool) }
    let file = (write-file ($dir | path join $"file.($case.ext)"))

    let checks = ($case | get --optional checks | default true)

    let result = (run-files [$file] $dir --path [$tools] --checks=$checks)

    let expected = (
      $case.calls
      | each {|call|
        let takes_path = ($call | get --optional 2 | default true)
        {bin: $call.0, args: (if $takes_path { [...$call.1 $file] } else { $call.1 })}
      }
    )
    let actual = (
      $result.calls
      | each {|call| {bin: ($call.bin | path basename), args: $call.args} }
    )
    assert equal $actual $expected $"extension ($case.ext) with ($case.tools), checks ($checks)"
    assert equal $result.run.stdout "[]\n"
  }
}

def "test tools run from the repository root of the edited file" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  let tools = ($repo | path join tools)
  install-stub ($tools | path join cargo)
  let file = (write-file ($repo | path join crate src lib.rs))

  let calls = (file-calls $file (mktemp --directory) --path [$tools])

  assert equal ($calls | get cwd) [$repo $repo]
}

def "test tools outside a repository run from the directory of the edited file" [] {
  let dir = (mktemp --directory | path expand)
  let file = (write-file ($dir | path join docs notes.md))

  let calls = (file-calls $file (mktemp --directory))

  let docs = ($dir | path join docs)
  assert equal ($calls | get cwd) [$docs $docs $docs]
}

def "test worktree markdown discovers config locally and runs checks from its root" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  ^git -C $repo -c user.name=test -c user.email=test@test commit --quiet --allow-empty -m init
  let worktree = ($repo | path join .claude worktrees wt)
  ^git -C $repo worktree add --quiet --detach $worktree
  let file = (write-file ($worktree | path join docs notes.md))

  let calls = (file-calls $file $repo)

  assert equal ($calls | get cwd) [($file | path dirname) $worktree $worktree]
}

def "test paths are normalized and cargo runs once per root" [] {
  let repo = (mktemp --directory | path expand)
  ^git -C $repo init --quiet
  let tools = ($repo | path join tools)
  let cargo = (install-stub ($tools | path join cargo))
  write-file ($repo | path join "--a.rs")
  let nix = (write-file ($repo | path join b.nix))
  write-file ($repo | path join c.rs)
  let shell = (write-file ($repo | path join d.sh))
  mkdir ($repo | path join directory.nix)
  let paths = [c.rs ./--a.rs b.nix ././--a.rs ./b.nix d.sh missing.nix directory.nix]

  let result = (run-files $paths $repo --path [$tools] --checks)

  let bin = $result.bin
  let expected = (cargo-calls $cargo $repo | append [
    {bin: ($bin | path join nixfmt), cwd: $repo, args: [$nix]}
    {bin: ($bin | path join shfmt), cwd: $repo, args: ["-w" $shell]}
    {bin: ($bin | path join shellcheck), cwd: $repo, args: ["--format" "gcc" $shell]}
  ])
  assert equal $result.calls $expected
  assert equal $result.run.stdout "[]\n"
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
  ] | each {|path| write-file $path })

  let result = (run-files $files $dir --path [($cargo | path dirname)] --checks)

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
  ] | each {|path| write-file $path })

  let result = (run-files $files $dir --path [($cargo | path dirname)] --checks)

  let expected = (cargo-calls $cargo $first | append (cargo-calls $cargo $second))
  assert equal $result.calls $expected
}

def "test missing cargo leaves file checks running" [] {
  let dir = (mktemp --directory | path expand)
  let rust = (write-file ($dir | path join a.rs))
  let nix = (write-file ($dir | path join b.nix))

  let result = (run-files [$rust $nix] $dir --checks)

  let nixfmt = ($result.bin | path join nixfmt)
  assert equal $result.calls [{bin: $nixfmt, cwd: $dir, args: [$nix]}]
  assert equal $result.run.stdout "[]\n"
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
  ] | each {|path| write-file $path })
  let cargo_dir = ($cargo | path dirname)
  let failure = "cargo fmt --all --quiet"

  let result = (run-files $files $dir --path [$cargo_dir] --checks --fail $failure --exit-code 1)

  let expected = (cargo-calls $cargo $first | append (cargo-calls $cargo $second))
  assert equal $result.calls $expected
  let reports = [
    $"cargo exited with 7 on ($first | path join a.rs):\nstub failure"
    $"cargo exited with 7 on ($second | path join a.rs):\nstub failure"
  ]
  assert equal ($result.run.stdout | from json) $reports
}

def "test project environment loads once from invocation cwd before checks" [] {
  let dir = (mktemp --directory | path expand)
  let repo = ($dir | path join repo)
  mkdir $repo
  ^git -C $repo init --quiet
  let cargo = (install-stub ($dir | path join tools cargo))
  let file = (write-file ($repo | path join src lib.rs))
  let exported = {PATH: ($cargo | path dirname), STUB_FAIL: null}
  let failure = "cargo fmt --all --quiet"

  let result = (run-files [$file] $dir --checks --direnv --export $exported --fail $failure)

  let direnv = ($result.bin | path join direnv)
  let expected = (
    [{bin: $direnv, cwd: $dir, args: [export json]}]
    | append (cargo-calls $cargo $repo)
  )
  assert equal $result.calls $expected
  assert equal $result.run.stdout "[]\n"
}

def "test failed environment loading stops checks" [] {
  let dir = (mktemp --directory | path expand)
  let file = (write-file ($dir | path join file.nix))

  let result = (run-files [$file] $dir --checks --direnv --fail "direnv export json" --exit-code 1)

  let direnv = ($result.bin | path join direnv)
  assert equal $result.calls [{bin: $direnv, cwd: $dir, args: [export json]}]
  assert equal ($result.run.stdout | from json) ["direnv exited with 7:\nstub failure"]
}

def "test project tools use the nearest executable including ancestors" [] {
  let cases = [
    {tool: prettier, ext: ts, args: ["--log-level" "warn" "--write"]}
    {tool: cspell, ext: md, args: ["--no-progress" "--no-must-find-files"]}
  ]

  for case in $cases {
    for local in [false true] {
      let dir = (mktemp --directory | path expand)
      let parent = (install-stub ($dir | path join node_modules .bin $case.tool))
      let nearest = if $local {
        install-stub ($dir | path join docs node_modules .bin $case.tool)
      } else {
        $parent
      }
      let file = (write-file ($dir | path join docs $"notes.($case.ext)"))

      let calls = (file-calls $file $dir)

      let selected = ($calls | where ($it.bin | path basename) == $case.tool)
      assert equal $selected [
        {bin: $nearest, cwd: ($file | path dirname), args: [...$case.args $file]}
      ] $"($case.tool) for ($case.ext) with local executable ($local)"
    }
  }
}

def "test markdown aligns tables and preserves fenced examples" [] {
  let formatter = (which format-files | get 0.path)
  let dir = (mktemp --directory | path expand)
  install-stub ($dir | path join node_modules .bin prettier)
  let log = ($dir | path join prettier.jsonl)
  let file = ($dir | path join notes.md)
  (
    '
    _Emphasis_

    | Name | Value |
    | --- | --- |
    | a | longer |

    ```json
    {"a":1,"b":[2,3]}
    ```

    - Example:

      ```ts
      const x={a:1,b:[2,3]}
      ```
    '
    | str dedent
  ) | save $file

  let run = with-env {DPRINT_CACHE_DIR: ($dir | path join cache), STUB_LOG: $log} {
    cd $dir
    ^$formatter $file | complete
  }
  assert equal $run.exit_code 0 $run.stderr

  assert equal (open --raw $file) (
    '
    _Emphasis_

    | Name | Value  |
    | ---- | ------ |
    | a    | longer |

    ```json
    {"a":1,"b":[2,3]}
    ```

    - Example:

      ```ts
      const x={a:1,b:[2,3]}
      ```

    '
    | str dedent
  )
  assert equal $run.stdout "[]\n"
  assert (not ($log | path exists))
}

def "test formatter failures report and keep later checks running" [] {
  let cases = [
    {ext: sh, failure: "shfmt -w", tools: [shfmt shellcheck]}
    {ext: py, failure: "ruff format", tools: [ruff ruff pyright]}
    {ext: md, failure: "dprint fmt --allow-no-files", tools: [dprint markdownlint cspell]}
  ]

  for case in $cases {
    for checks in [false true] {
      let dir = (mktemp --directory | path expand)
      let file = (write-file ($dir | path join $"notes.($case.ext)"))
      let failure = $"($case.failure) ($file)"

      let result = (run-files [$file] $dir --checks=$checks --fail $failure --exit-code 1)

      let tools = if $checks { $case.tools } else { $case.tools | first 1 }
      let report = $"($case.tools.0) exited with 7 on ($file):\nstub failure"
      assert equal ($result.calls | get bin | path basename) $tools $case.ext
      assert equal ($result.run.stdout | from json) [$report] $case.ext
    }
  }
}
