#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Hook
# ==================================================================================================

def collect-paths [input: record, parser: string]: nothing -> list<string> {
  let args = $input.tool_input
  if $input.tool_name == "apply_patch" {
    $args.command | ^$parser | from json | where action != "Delete" | get path
  } else {
    [$args.file_path]
  }
}

def format-edited [config: record]: nothing -> any {
  let input = (^cat | from json)
  cd $input.cwd
  # Nushell's main parser has no `--` separator for flag-shaped relative paths.
  let paths = (
    collect-paths $input $config.patchInput
    | each {|path| if ($path | str starts-with "-") { $"./($path)" } else { $path } }
  )
  if ($paths | is-empty) { return null }

  let formatter = $config.fileFormatter
  let run = (^$formatter --checks ...$paths | complete)
  if ($run.stderr | is-not-empty) { print --stderr --no-newline $run.stderr }
  let reports = ($run.stdout | from json)
  if ($reports | is-empty) { return null }

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
  if $out != null { print $out }
}
