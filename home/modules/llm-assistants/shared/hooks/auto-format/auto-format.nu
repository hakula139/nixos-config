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
  let paths = (collect-paths $input $config.patchInput)
  if ($paths | is-empty) { return null }

  let formatter = $config.fileFormatter
  let run = (^$formatter ...$paths | complete)
  if ($run.stderr | is-not-empty) { print --stderr --no-newline $run.stderr }
  let report = ($run.stdout | str trim)
  if ($report | is-empty) { return null }

  {
    hookSpecificOutput: {
      hookEventName: "PostToolUse"
      additionalContext: $report
    }
  }
  | to json --raw
}

def main [config_file: string] {
  let out = (try { format-edited (open $config_file) } catch { null })
  if $out != null { print $out }
}
