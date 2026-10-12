#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format and Lint
# ==================================================================================================

const MAX_LINES = 10

# Dev-only tools are empty strings on non-dev hosts.
def have [tool: string]: nothing -> bool {
  which $tool | is-not-empty
}

# One `try` each, so a crashing tool cannot skip the ones after it. Only a failing exit reports, so a
# linter that exits 0 on warnings needs the flag that fails it.
def check [tool: string, args: list<string>, path: string]: nothing -> string {
  let run = (try { ^$tool ...$args | complete } catch { null })
  if $run == null or $run.exit_code == 0 {
    return ""
  }
  # A bare store path such as `<hash>-nu-check`.
  let name = ($tool | path basename | str replace --regex '^[0-9a-z]{32}-' "")
  let output = ($run.stdout + $run.stderr | lines | first $MAX_LINES | str join "\n")
  $"($name) exited with ($run.exit_code) on ($path):\n($output)"
}

# Node's own resolution order, since eslint only works with its own project's config and plugins.
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

# A `--fix` pass reports whatever it could not fix, so one call covers both.
def format-file [path: string, config: record]: nothing -> list<any> {
  match ($path | path parse | get extension) {
    "sh" => [
      (check $config.shfmt ["-w" $path] $path)
      (check $config.shellcheck ["--format" "gcc" $path] $path)
    ]
    "nix" => [
      (check $config.nixfmt [$path] $path)
    ]
    "nu" => [
      (check $config.nuCheck [$path] $path)
    ]
    "py" => [
      (if (have $config.ruff) {
        [
          (check $config.ruff ["format" $path] $path)
          (check $config.ruff ["check" "--fix" "--output-format" "concise" $path] $path)
        ]
      })
      (if (have $config.pyright) {
        check $config.pyright ["--warnings" $path] $path
      })
    ]
    # Rust and Go stay unpinned, since either toolchain would add GiBs to every host's closure.
    "rs" => [
      (if (have cargo) {
        [
          (check cargo ["fmt" "--all" "--quiet"] $path)
          (check cargo ["clippy" "--all-targets" "--quiet" "--" "-D" "warnings"] $path)
        ]
      })
    ]
    "go" => [
      (if (have goimports) {
        check goimports ["-w" $path] $path
      } else if (have gofmt) {
        check gofmt ["-w" $path] $path
      })
    ]
    "toml" => [
      (if (have $config.taplo) {
        check $config.taplo ["fmt" $path] $path
      })
    ]
    "css" | "scss" | "less" | "js" | "jsx" | "mjs" | "cjs" | "ts" | "tsx" | "vue" => {
      # A pinned prettier cannot load the plugins the project's config names.
      let prettier = (project-bin $path "prettier")
      let formatter = if ($prettier | is-not-empty) { $prettier } else { $config.prettier }
      # A file the project ignores is not this hook's business.
      let eslint = (project-bin $path "eslint")
      [
        (if (have $formatter) {
          check $formatter ["--log-level" "warn" "--write" $path] $path
        })
        (if ($eslint | is-not-empty) {
          check $eslint ["--fix" "--max-warnings" "0" "--no-warn-ignored" $path] $path
        })
      ]
    }
    "md" => [
      (if (have $config.dprint) {
        format-markdown $path $config
        [
          (check $config.markdownlint ["--fix" $path] $path)
          (check $config.cspell ["--no-progress" $path] $path)
        ]
      })
    ]
    _ => []
  }
}

def collect-files [input: record, config: record]: nothing -> list<string> {
  let args = $input.tool_input
  let paths = if $input.tool_name == "apply_patch" {
    let parser = $config.patchInput
    $args.command | ^$parser | from json | where action != "Delete" | get path
  } else {
    [$args.file_path]
  }
  $paths
  | each {|path| $path | path expand }
  | sort
  | uniq
  | where ($it | path type) == "file"
}

# Apply the approved project environment, returning false when loading fails.
def --env load-project-env [direnv: string]: nothing -> bool {
  if ($direnv | is-empty) {
    return true
  }

  let exported = (^$direnv export json | complete)
  if $exported.exit_code != 0 {
    print --stderr --no-newline $exported.stderr
    return false
  }
  if ($exported.stdout | is-not-empty) {
    let changes = ($exported.stdout | from json)
    for name in ($changes | columns) {
      let value = ($changes | get $name)
      if $value == null {
        hide-env --ignore-errors $name
      } else {
        load-env { $name: $value }
      }
    }
  }
  true
}

def --env format-edited [config: record]: nothing -> any {
  let input = (^cat | from json)
  cd $input.cwd
  if not (load-project-env $config.direnv) {
    return null
  }

  let reports = (
    collect-files $input $config
    | each {|path| format-file $path $config }
    | flatten
    | flatten
    | compact --empty
  )
  if ($reports | is-empty) {
    return null
  }
  {
    hookSpecificOutput: {
      hookEventName: "PostToolUse"
      additionalContext: (
        ["Formatters and linters reported problems in the edited files." ...$reports]
        | str join "\n\n"
      )
    }
  }
  | to json --raw
}

def main [config_file: string] {
  let out = (try { format-edited (open $config_file) } catch { null })
  if $out != null {
    print $out
  }
}
