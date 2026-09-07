#!/usr/bin/env nu

# ==============================================================================
# Patch Input
# ==============================================================================

def parse-patch [command: string]: nothing -> list<record> {
  let lines = ($command | lines)
  mut files = []
  mut current = null
  for line in $lines {
    # apply_patch file operation headers
    let header = ($line | parse --regex '^\*\*\* (?<action>Add|Update|Delete) File: (?<path>.+)$')
    if ($header | is-not-empty) {
      if $current != null { $files = ($files | append $current) }
      $current = ($header.0 | merge {added: []})
    } else if $current != null {
      if ($line | str starts-with "*** Move to: ") {
        $current.path = ($line | str replace "*** Move to: " "")
      }
      if ($line | str starts-with "+") {
        $current.added = ($current.added | append ($line | str substring 1..))
      }
    }
  }
  if $current != null { $files = ($files | append $current) }
  $files
}

# Read an apply_patch payload from stdin and emit file changes as JSON.
def main [] {
  let command = (^cat)
  parse-patch $command | to json --raw | print
}
