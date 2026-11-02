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
    ^git -C $dir rev-parse --path-format=absolute --show-toplevel --git-path hooks/pre-commit
    | complete
  )
  if $query.exit_code != 0 { return "" }
  let lines = ($query.stdout | lines)
  let root = $lines.0
  let hook = $lines.1
  let configs = [.pre-commit-config.yaml .pre-commit-config.yml prek.toml]
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
      $blocks | where $it =~ '(?m)^- exit code:'
    }
  )
  $failed
  | each {|block| $block | str trim | lines | first $MAX_LINES | str join "\n" }
}

# Run the gate in `root` through direnv when the repository's `.envrc` is allowed, so
# `language: system` hooks see the dev shell a human commit would. `direnv exec` restores the
# caller's pre-direnv PATH, dropping this wrapper's entries too, so call prek by its resolved path.
def run-gate [root: string, paths: list<string>, --via-direnv]: nothing -> record {
  let prek = (which prek | get 0.path)
  let args = [run --quiet --no-progress --color never --cd $root --files ...$paths]
  if $via_direnv {
    ^direnv exec $root $prek ...$args | complete
  } else {
    ^$prek ...$args | complete
  }
}

# The hooks that fail on `paths` after a confirming rerun.
def check [root: string, paths: list<string>]: nothing -> list<string> {
  let status = (do { cd $root; ^direnv status --json } | from json)
  let allowed = ($status.state.foundRC?.allowed? == 0)
  let gate = {||
    let run = (run-gate $root $paths --via-direnv=$allowed)
    if $run.exit_code == 0 {
      []
    } else {
      failed-blocks ($run.stderr + $run.stdout)
    }
  }
  if (do $gate | is-empty) { return [] }
  # Fixers such as end-of-file-fixer exit nonzero after a rewrite, so a second run confirms.
  do $gate
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
