#!/usr/bin/env nu

# ==============================================================================
# Patch Input
# ==============================================================================

def parse-patch [command: string]: nothing -> list<record> {
  let lines = ($command | lines)
  if ($lines | first | default "") != "*** Begin Patch" or ($lines | last | default "") != "*** End Patch" {
    return []
  }
  mut files = []
  mut current = null
  for row in ($lines | enumerate) {
    # apply_patch file operation headers
    let header = ($row.item | parse --regex '^\*\*\* (?<action>Add|Update|Delete) File: (?<path>.+)$')
    if ($header | is-not-empty) {
      if $current != null { $files = ($files | append $current) }
      $current = ($header.0 | merge {start: ($row.index + 1), end: ($row.index + 1), added: []})
    } else if $current != null {
      if ($row.item | str starts-with "*** Move to: ") {
        $current.path = ($row.item | str replace "*** Move to: " "")
      }
      if ($row.item | str starts-with "+") {
        $current.added = ($current.added | append {index: $row.index, text: ($row.item | str substring 1..)})
      }
      if $row.item != "*** End Patch" { $current.end = ($row.index + 1) }
    }
  }
  if $current != null { $files = ($files | append $current) }
  $files
}

def main [] {
  try { let command = (^cat); parse-patch $command | to json --raw | print } catch { print '[]' }
}
