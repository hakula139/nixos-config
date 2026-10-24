#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format and Lint
# ==================================================================================================

const MAX_LINES = 10

# Dev-only tools are empty strings on non-dev hosts.
def have [tool: string]: nothing -> bool {
  which $tool | is-not-empty
}

# One `try` each, so a crashing tool cannot skip the ones after it. Only a failing exit reports, so
# a linter that exits 0 on warnings needs the flag that fails it.
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

# The nearest file matching `names` above `path`, or an empty string.
def project-file [path: string, names: list<string>]: nothing -> string {
  let parts = ($path | path expand | path dirname | path split)
  for n in (($parts | length)..1) {
    for name in $names {
      let candidate = ([($parts | first $n | path join) $name] | path join)
      if ($candidate | path exists) { return $candidate }
    }
  }
  ""
}

# The nearest `node_modules/.bin/<tool>` above `path`, or an empty string.
def project-bin [path: string, tool: string]: nothing -> string {
  project-file $path [(["node_modules" ".bin" $tool] | path join)]
}

# The root of the repository holding `path`, or its directory outside a repository. Tools such as
# markdownlint-cli2 read their config only from the working directory down, so they run from here.
def project-root [path: string, git: string]: nothing -> string {
  let dir = ($path | path dirname)
  let toplevel = (^$git -C $dir rev-parse --show-toplevel | complete)
  if $toplevel.exit_code == 0 { $toplevel.stdout | str trim } else { $dir }
}

def format-markdown [path: string, config: record]: nothing -> string {
  # Keep dprint's table alignment even in projects that use Prettier.
  let selected = (
    project-file $path [dprint.json dprint.jsonc .dprint.json .dprint.jsonc]
    | default --empty $config.dprintConfig
  )
  check $config.dprint ["fmt" "--allow-no-files" "--config" $selected $path] $path
}

# A `--fix` pass reports whatever it could not fix, so one call covers both. Each file's tools run
# from its own project, never the session's.
def format-file [path: string, root: string, config: record]: nothing -> list<string> {
  cd $root
  let reports = match ($path | path parse | get extension) {
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
      let formatter = (project-bin $path "prettier" | default --empty $config.prettier)
      # eslint only works with its own project's config and plugins.
      let eslint = (project-bin $path "eslint")
      [
        (if (have $formatter) {
          check $formatter ["--log-level" "warn" "--write" $path] $path
        })
        (if ($eslint | is-not-empty) {
          # A file the project ignores is not this hook's business.
          check $eslint ["--fix" "--max-warnings" "0" "--no-warn-ignored" $path] $path
        })
      ]
    }
    "md" => [
      (if (have $config.dprint) {
        let cspell = (project-bin $path "cspell" | default --empty $config.cspell)
        [
          (format-markdown $path $config)
          (check $config.markdownlint ["--config" $config.markdownlintConfig "--fix" $path] $path)
          # A file the project excludes from spell checking is not this hook's business.
          (check $cspell ["--no-progress" "--no-must-find-files" $path] $path)
        ]
      })
    ]
    _ => []
  }
  $reports | flatten | compact --empty
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

  mut rust_roots = []
  mut reports = []
  for path in (collect-files $input $config) {
    let root = (project-root $path $config.git)
    if ($path | path parse | get extension) == "rs" {
      if $root in $rust_roots { continue }
      $rust_roots = ($rust_roots | append $root)
    }
    $reports = ($reports | append (format-file $path $root $config))
  }
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
