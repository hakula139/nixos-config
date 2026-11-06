#!/usr/bin/env nu

# ==================================================================================================
# Workmux Stub
# ==================================================================================================
# Records each invocation and answers from `STUB_EXISTING_PATH`, `STUB_ADD_PATH`, and
# `STUB_REMOVE_PATH`. `path` fails unless `STUB_EXISTING_PATH` is set, `add` prints a receipt for
# `STUB_ADD_PATH`, and `remove` deletes `STUB_REMOVE_PATH` unless `STUB_REMOVE_LEAVES` is set.
# ==================================================================================================

def --wrapped main [...args: string] {
  {cwd: $env.PWD, args: $args}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  let command = ($args | get -o 0 | default "")
  match $command {
    "path" => {
      let path = ($env.STUB_EXISTING_PATH? | default "")
      if ($path | is-empty) {
        print --stderr "Worktree not found"
        exit 1
      }
      print $path
    }
    "add" => {
      {schema_version: 1, worktree_path: $env.STUB_ADD_PATH} | to json --raw
    }
    "remove" => {
      let leaves = ($env.STUB_REMOVE_LEAVES? | default "")
      if ($leaves | is-empty) {
        ^rm --recursive --force $env.STUB_REMOVE_PATH
        exit 0
      }
    }
    _ => { }
  }
}
