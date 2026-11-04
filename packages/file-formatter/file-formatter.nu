#!/usr/bin/env nu

# ==================================================================================================
# File Formatter
# ==================================================================================================

const MAX_LINES = 20
const REPORT_PREFIX = "The pre-commit hooks reported problems in the edited files."

# The root of the repository holding `path` when that repository opts in with an installed
# pre-commit hook and a config at its root, or an empty string.
def gate-root [path: string]: nothing -> string {
  let dir = ($path | path dirname)
  let query = (
    ^git -C $dir rev-parse --path-format=absolute --show-toplevel --git-path "hooks/pre-commit"
    | complete
  )
  if $query.exit_code != 0 { return "" }
  let lines = ($query.stdout | lines)
  let root = $lines.0
  let hook = $lines.1
  let configs = [".pre-commit-config.yaml" ".pre-commit-config.yml" "prek.toml"]
  if ($hook | path exists) and ($configs | any {|name| $root | path join $name | path exists }) {
    $root
  } else {
    ""
  }
}

# The failed hook blocks in prek's output. Without a block header, as with a config error, the
# whole output is the report.
def failed-blocks [output: string]: nothing -> list<string> {
  # A failed hook's header line, such as `cspell.......Failed`.
  let blocks = (
    $output
    | split row --regex '(?m)^(?=\S.*\.{3,}Failed$)'
    | skip 1
  )
  let failed = (
    if ($blocks | is-empty) {
      [$output]
    } else {
      $blocks | where $it =~ "(?m)^- exit code:"
    }
  )
  $failed
  | each {|block| $block | str trim | lines | first $MAX_LINES | str join "\n" }
}

# Run `hooks`, or every hook when the list is empty, on `paths` in `root`. The run goes through
# direnv when the repository's `.envrc` is allowed, so `language: system` hooks see the dev shell a
# human commit would. `direnv exec` restores the caller's pre-direnv PATH, dropping this wrapper's
# entries too, so call prek by its resolved path.
def run-gate [
  root: string
  paths: list<string>
  hooks: list<string>
  --via-direnv
]: nothing -> record {
  let prek = (which prek | get 0.path)
  let args = [
    run ...$hooks
    --quiet
    --no-progress
    --color never
    --cd $root
    --files ...$paths
  ]
  if $via_direnv {
    ^direnv exec $root $prek ...$args | complete
  } else {
    ^$prek ...$args | complete
  }
}

# A digest per file path, so a rerun can tell whether a hook rewrote one.
def path-digests [paths: list<string>]: nothing -> list<string> {
  $paths
  | where {|path| ($path | path type) == "file" }
  | each {|path| open --raw $path | hash sha256 }
}

# The ids of the hooks that failed in `output`.
def failed-hooks [output: string]: nothing -> list<string> {
  $output
  | parse --regex "(?m)^- hook id: (?<id>.+)$"
  | get id
}

# The hooks that fail on `paths`.
def check [root: string, paths: list<string>]: nothing -> list<string> {
  let status = (do { cd $root; ^direnv status --json } | from json)
  let allowed = ($status.state.foundRC?.allowed? == 0)
  let before = (path-digests $paths)
  let first = (run-gate $root $paths [] --via-direnv=$allowed)
  if $first.exit_code == 0 { return [] }
  let output = ($first.stderr + $first.stdout)
  if (path-digests $paths) == $before { return (failed-blocks $output) }
  # A fixer such as end-of-file-fixer exits nonzero after a rewrite, so rerun the hooks that failed
  # to confirm the result.
  let confirm = (run-gate $root $paths (failed-hooks $output) --via-direnv=$allowed)
  if $confirm.exit_code == 0 { [] } else { failed-blocks ($confirm.stderr + $confirm.stdout) }
}

# The failed hooks across the repositories holding `paths`. A path outside a repository, or in one
# without an installed hook and config, is skipped.
def format-paths [paths: list<string>]: nothing -> list<string> {
  $paths
  | path expand
  | group-by {|path| gate-root $path }
  | reject --optional ""
  | items {|root, paths| check $root $paths }
  | flatten
}

# Report the hooks that fail on the given files.
def --wrapped main [
  ...paths: string # Files to check.
] {
  let reports = (format-paths $paths)
  if ($reports | is-empty) { return }
  print ([$REPORT_PREFIX ...$reports] | str join "\n\n")
  exit 1
}
