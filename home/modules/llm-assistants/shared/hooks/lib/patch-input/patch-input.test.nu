#!/usr/bin/env nu

# ==================================================================================================
# Patch Input Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join patch-input.nu)

def parse-patch [patch: string]: nothing -> list<record> {
  $patch | ^$nu.current-exe --no-config-file $SCRIPT | from json
}

def "test reports each file with only its added lines" [] {
  let patch = [
    "*** Begin Patch"
    "*** Add File: docs/new.md"
    "+# Title"
    "+"
    "+Body"
    "*** Update File: src/old.rs"
    "*** Move to: src/new.rs"
    "@@ fn main() {"
    " let kept = 1;"
    "-let removed = 2;"
    "+let added = 3;"
    "*** Delete File: src/gone.rs"
    "*** End Patch"
  ]

  assert equal (parse-patch ($patch | str join "\n")) [
    {action: Add, path: docs/new.md, added: ["# Title" "" Body]}
    {action: Update, path: src/new.rs, added: ["let added = 3;"]}
    {action: Delete, path: src/gone.rs, added: []}
  ]
}
