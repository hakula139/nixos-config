#!/usr/bin/env nu

# ==============================================================================
# Auto-Format and Lint (PostToolUse)
# ==============================================================================

const MAX_LINES = 20

# Dev-only tools are empty strings on non-dev hosts.
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

# Node's own resolution order, since eslint only works with the config and the
# plugins its project installed.
def project-bin [path: string, tool: string]: nothing -> string {
  let parts = ($path | path expand | path dirname | path split)
  for n in (($parts | length)..1) {
    let candidate = ([($parts | first $n | path join) "node_modules" ".bin" $tool] | path join)
    if ($candidate | path exists) { return $candidate }
  }
  ""
}

def format-markdown [path: string, config: record] {
  try {
    let dprint = $config.dprint
    let run = (
      open --raw $path
      | ^$dprint fmt --config $config.dprintConfig --stdin md
      | complete
    )
    if $run.exit_code == 0 and ($run.stdout | is-not-empty) {
      $run.stdout | save --force --raw $path
    }
  } catch { null }
}

def format-file [path: string, config: record] {
  match ($path | path parse | get extension) {
    "sh" => {
      quiet $config.shfmt ["-w" $path]
      capped $config.shellcheck [$path]
    }
    "nix" => {
      quiet $config.nixfmt [$path]
    }
    "nu" => {
      capped $config.nuCheck [$path]
    }
    "py" => {
      if (have $config.ruff) {
        quiet $config.ruff ["format" $path]
        quiet $config.ruff ["check" "--fix" $path]
        capped $config.ruff ["check" $path]
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
      if (have $config.taplo) {
        quiet $config.taplo ["fmt" $path]
      }
    }
    "css" | "scss" | "less" | "js" | "jsx" | "mjs" | "cjs" | "ts" | "tsx" | "vue" => {
      # A pinned prettier cannot load the plugins the project's config names.
      let prettier = (project-bin $path "prettier")
      let formatter = if ($prettier | is-not-empty) { $prettier } else { $config.prettier }
      if (have $formatter) {
        quiet $formatter ["--log-level" "warn" "--write" $path]
      }
      # `--fix` reports whatever it could not fix, so one call covers both. A
      # file the project ignores is not this hook's business.
      let eslint = (project-bin $path "eslint")
      if ($eslint | is-not-empty) {
        capped $eslint ["--fix" "--no-warn-ignored" $path]
      }
    }
    "md" => {
      if (have $config.dprint) {
        format-markdown $path $config
        quiet $config.markdownlint ["--fix" $path]
        capped $config.markdownlint [$path]
        capped $config.cspell ["--no-progress" $path]
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
    # File paths in apply_patch headers
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

def format-edited [config: record] {
  let input = (^cat | from json)
  if ($input | describe | str starts-with "record") == false {
    return
  }
  for path in (collect-files $input) {
    format-file $path $config
  }
}

def main [config_file: string] {
  try { format-edited (open $config_file) } catch { null }
}
