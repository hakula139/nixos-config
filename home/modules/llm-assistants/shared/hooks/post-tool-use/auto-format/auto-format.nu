#!/usr/bin/env nu

# ==============================================================================
# Auto-Format and Lint (PostToolUse)
# ==============================================================================

const NIXFMT = "@nixfmt@"
const NU_CHECK = "@nuCheck@"
const SHELLCHECK = "@shellcheck@"
const SHFMT = "@shfmt@"

const CSPELL = "@cspell@"
const DPRINT = "@dprint@"
const DPRINT_CONFIG = "@dprintConfig@"
const MARKDOWNLINT = "@markdownlint@"
const PRETTIER = "@prettier@"
const RUFF = "@ruff@"
const TAPLO = "@taplo@"

const MAX_LINES = 20

def have [tool: string]: nothing -> bool {
  which $tool | is-not-empty
}

# One `try` each, so a crashing tool cannot skip the ones after it.
def quiet [tool: string, args: list<string>] {
  print --no-newline (try { ^$tool ...$args | complete | get stdout } catch { "" })
}

def capped [tool: string, args: list<string>] {
  let merged = (
    try {
      let run = (^$tool ...$args | complete)
      $run.stdout + $run.stderr
    } catch { "" }
  )
  print --no-newline (
    $merged | lines | first $MAX_LINES | each {|line| $line + "\n" } | str join
  )
}

def format-markdown [path: string] {
  try {
    let run = (
      open --raw $path
      | ^$DPRINT fmt --config $DPRINT_CONFIG --stdin md
      | complete
    )
    if $run.exit_code == 0 and ($run.stdout | is-not-empty) {
      $run.stdout | save --force --raw $path
    }
  } catch { null }
}

def format-file [path: string] {
  match ($path | path parse | get extension) {
    "sh" => {
      quiet $SHFMT ["-w" $path]
      capped $SHELLCHECK [$path]
    }
    "nix" => {
      quiet $NIXFMT [$path]
    }
    "nu" => {
      capped $NU_CHECK [$path]
    }
    "py" => {
      if (have $RUFF) {
        quiet $RUFF ["format" $path]
        quiet $RUFF ["check" "--fix" $path]
        capped $RUFF ["check" $path]
      }
    }
    # Rust and Go stay unpinned, since either toolchain would add GiBs to every
    # host's closure.
    "rs" => {
      if (have cargo) {
        quiet cargo ["fmt" "--all" "--quiet"]
        capped cargo ["clippy" "--all-targets" "--quiet" "--" "-D" "warnings"]
      }
    }
    "go" => {
      if (have goimports) {
        quiet goimports ["-w" $path]
      } else if (have gofmt) {
        quiet gofmt ["-w" $path]
      }
    }
    "toml" => {
      if (have $TAPLO) {
        quiet $TAPLO ["fmt" $path]
      }
    }
    "css" | "js" => {
      if (have $PRETTIER) {
        quiet $PRETTIER ["--write" $path]
      }
    }
    "md" => {
      if (have $DPRINT) {
        format-markdown $path
        quiet $MARKDOWNLINT ["--fix" $path]
        capped $MARKDOWNLINT [$path]
        capped $CSPELL ["--no-progress" $path]
      }
    }
  }
}

def collect-files [input: record]: nothing -> list<string> {
  let args = ($input | get -o tool_input | default {})
  if ($args | describe | str starts-with "record") == false {
    return []
  }
  let paths = if ($input | get -o tool_name | default "") == "apply_patch" {
    $args
    | get -o command
    | default ""
    | lines
    | parse --regex '^\*\*\* (?:Add|Update) File: (?<path>.*)$'
    | get -o path
    | default []
  } else {
    [($args | get -o file_path | default "")]
  }
  $paths
  | where ($it | is-not-empty)
  | sort
  | uniq
  | where ($it | path expand | path type) == "file"
}

def format-edited [] {
  # `open /dev/stdin` re-opens fd 0 by path and raises ENXIO once the caller
  # passes a socket, which is what Node's `spawn` hands a hook.
  let input = (^cat | from json)
  if ($input | describe | str starts-with "record") == false {
    return
  }
  for path in (collect-files $input) {
    format-file $path
  }
}

def main [] {
  try { format-edited } catch { null }
}
