#!/usr/bin/env nu

# ==================================================================================================
# File Formatter
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

# The nearest `node_modules/.bin/<tool>` above `path`, or an empty string.
def project-bin [path: string, tool: string]: nothing -> string {
  let parts = ($path | path expand | path dirname | path split)
  for n in (($parts | length)..1) {
    let candidate = ([($parts | first $n | path join) "node_modules" ".bin" $tool] | path join)
    if ($candidate | path exists) { return $candidate }
  }
  ""
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
  cd ($path | path dirname)
  with-env {DPRINT_CONFIG_DIR: $config.dprintConfigDir} {
    check $config.dprint ["fmt" "--allow-no-files" $path] $path
  }
}

# A `--fix` pass reports whatever it could not fix, so one call covers both. Each file's tools run
# from its own project.
def format-file [path: string, root: string, config: record, --checks]: nothing -> list<string> {
  cd $root
  let reports = match ($path | path parse | get extension) {
    "sh" => [
      (check $config.shfmt ["-w" $path] $path)
      (if $checks { check $config.shellcheck ["--format" "gcc" $path] $path })
    ]
    "nix" => [
      (check $config.nixfmt [$path] $path)
    ]
    "nu" => [
      (if $checks { check $config.nuCheck [$path] $path })
    ]
    "py" => [
      (if (have $config.ruff) {
        [
          (check $config.ruff ["format" $path] $path)
          (if $checks { check $config.ruff ["check" "--fix" "--output-format" "concise" $path] $path })
        ]
      })
      (if $checks and (have $config.pyright) {
        check $config.pyright ["--warnings" $path] $path
      })
    ]
    # Rust and Go stay unpinned, since either toolchain would add GiBs to every host's closure.
    "rs" => [
      (if (have cargo) {
        [
          (check cargo ["fmt" "--all" "--quiet"] $path)
          (if $checks { check cargo ["clippy" "--all-targets" "--quiet" "--" "-D" "warnings"] $path })
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
      [
        (if (have $formatter) {
          check $formatter ["--log-level" "warn" "--write" $path] $path
        })
        (if $checks {
          # eslint only works with its own project's config and plugins.
          let eslint = (project-bin $path "eslint")
          if ($eslint | is-not-empty) {
            # A file the project ignores is not this formatter's business.
            check $eslint ["--fix" "--max-warnings" "0" "--no-warn-ignored" $path] $path
          }
        })
      ]
    }
    "md" => {
      if (have $config.dprint) {
        [
          (format-markdown $path $config)
          (if $checks {
            check $config.markdownlint ["--config" $config.markdownlintConfig "--fix" $path] $path
          })
          (if $checks {
            let cspell = (project-bin $path "cspell" | default --empty $config.cspell)
            # A file the project excludes from spell checking is not this formatter's business.
            check $cspell ["--no-progress" "--no-must-find-files" $path] $path
          })
        ]
      } else { [] }
    }
    _ => []
  }
  $reports | flatten | compact --empty
}

# Apply the approved project environment, returning a diagnostic when loading fails.
def --env load-project-env [direnv: string]: nothing -> string {
  if ($direnv | is-empty) {
    return ""
  }

  let exported = (^$direnv export json | complete)
  if $exported.exit_code != 0 {
    return $"direnv exited with ($exported.exit_code):\n($exported.stderr | str trim)"
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
  ""
}

def --env format-paths [paths: list<string>, config: record, --checks]: nothing -> list<string> {
  let problem = (load-project-env $config.direnv)
  if ($problem | is-not-empty) { return [$problem] }

  let files = (
    $paths
    | each {|path| $path | path expand }
    | sort
    | uniq
    | where ($it | path type) == "file"
  )
  mut rust_roots = []
  mut reports = []
  for path in $files {
    let root = (project-root $path $config.git)
    if ($path | path parse | get extension) == "rs" {
      if $root in $rust_roots { continue }
      $rust_roots = ($rust_roots | append $root)
    }
    $reports = ($reports | append (format-file $path $root $config --checks=$checks))
  }
  $reports
}

# Format files with their project tools. Include lint and type checks with `--checks`.
def main [config_file: string, ...paths: string, --checks] {
  let reports = (format-paths $paths (open $config_file) --checks=$checks)
  print ($reports | to json --raw)
  if ($reports | is-not-empty) { exit 1 }
}
