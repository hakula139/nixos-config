#!/usr/bin/env nu

# ==================================================================================================
# Compact Context
# ==================================================================================================
# Codex persists completed turn items to its rollout, so applied patches and the reads its own
# command parser recognized survive compaction there.
# ==================================================================================================

const MAX_MODIFIED = 30
const MAX_READ = 20

def turn-items [transcript: string]: nothing -> list<record> {
  open --raw $transcript
  | lines
  | where {|line|
    ($line | str contains '"item_completed"') and (
      ($line | str contains '"FileChange"') or ($line | str contains '"CommandExecution"')
    )
  }
  | each {|line| try { $line | from json } catch { null } }
  | where {|entry|
    (($entry | describe | str starts-with "record")
      and $entry.type? == "event_msg"
      and $entry.payload.type == "item_completed")
  }
  | get payload.item
}

def modified-files [items: list<record>]: nothing -> list<string> {
  $items
  | where {|item| $item.type == "FileChange" and $item.status? == "completed" }
  | each {|item|
    $item.changes
    | transpose path change
    | where change.type != "delete"
    | each {|row| $row.change.move_path? | default $row.path }
  }
  | flatten
}

# Codex keeps a leading `~` in parsed read paths.
def read-files [items: list<record>]: nothing -> list<string> {
  $items
  | where {|item| $item.type == "CommandExecution" and $item.status? == "completed" }
  | each {|item|
    let cwd = ($item.cwd | str replace --regex '^file://' '' | url decode)
    $item.parsed_cmd | where type == "read" | each {|cmd|
      let path = if ($cmd.path | str starts-with "~") { $cmd.path | path expand } else { $cmd.path }
      $cwd | path join $path
    }
  }
  | flatten
}

def newest-unique [paths: list<string>]: nothing -> list<string> {
  $paths | each { path expand --no-symlink } | reverse | uniq
}

def section [label: string, paths: list<string>, limit: int, cwd: string]: nothing -> any {
  if ($paths | is-empty) {
    return null
  }
  let shown = (
    $paths | first $limit | each {|path|
      let relative = (try { $path | path relative-to $cwd } catch { $path })
      $"- ($relative)"
    }
  )
  let omitted = (($paths | length) - ($shown | length))
  [$"($label):" ...$shown (if $omitted > 0 { $"- ... ($omitted) more" })]
  | compact
  | str join "\n"
}

def file-sections [transcript: string, cwd: string]: nothing -> list<string> {
  let items = (turn-items $transcript)
  let modified = (newest-unique (modified-files $items))
  let read = (newest-unique (read-files $items) | difference $modified)
  [
    (section "Files modified before compaction, most recent first" $modified $MAX_MODIFIED $cwd)
    (section "Files read through recognized shell commands, most recent first" $read $MAX_READ $cwd)
  ]
  | compact
}

# The rollout format carries no compatibility promise, so a record in an unexpected shape drops the
# file lists but keeps the transcript pointer.
def restore [config: record]: nothing -> any {
  let input = (^cat | from json)
  let transcript = ($input.transcript_path? | default "")
  if not ($transcript | path exists) {
    return null
  }

  let pointer = ($config.prompt | str replace '@transcriptPath@' $transcript | str trim)
  let sections = (try { file-sections $transcript $input.cwd } catch { [] })
  {
    hookSpecificOutput: {
      hookEventName: "SessionStart"
      additionalContext: ([$pointer ...$sections] | str join "\n\n")
    }
  }
  | to json --raw
}

def main [config_file: string] {
  let out = (try { restore (open $config_file) } catch { null })
  if $out != null {
    print $out
  }
}
