#!/usr/bin/env nu

# ==================================================================================================
# Patch Input Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join patch-input.nu)

def parse-patch [patch: string]: nothing -> list<record> {
  $patch | ^$nu.current-exe --no-config-file $SCRIPT | from json
}

def "test reports each file with only its added lines" [] {
  # A context line's one-space marker leaves it off the 2-space indent grid.
  # editorconfig-checker-disable
  let patch = (
    "
    *** Begin Patch
    *** Add File: docs/new.md
    +# Title
    +
    +Body
    *** Update File: src/old.rs
    *** Move to: src/new.rs
    @@ fn main() {
     let kept = 1;
    -let removed = 2;
    +let added = 3;
    *** Delete File: src/gone.rs
    *** End Patch
    "
    | str dedent
  )
  # editorconfig-checker-enable

  assert equal (parse-patch $patch) [
    {action: Add, path: docs/new.md, added: ["# Title" "" Body]}
    {action: Update, path: src/new.rs, added: ["let added = 3;"]}
    {action: Delete, path: src/gone.rs, added: []}
  ]
}
