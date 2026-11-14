#!/usr/bin/env nu

# ==================================================================================================
# Cursor Extension Sync Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "sync-extensions.nu")

const HEADER = "Extensions installed on WSL: example:\r\n"

def sync [
  listing: string
  --prune
  --server
  --no-cli
  --listing-exit: int = 0
  --failing-id: string = ""
]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "calls.jsonl")
  touch $log

  let server_dir = ($dir | path join ".cursor-server/bin")
  if $server {
    let cli_dir = ($server_dir | path join "0000/bin/remote-cli")
    mkdir $cli_dir
    cp ($env.NU_TEST_STUBS | path join "cursor") $cli_dir
  }

  let config = ($dir | path join "config.json")
  {
    baseExtensions: ["example.present" "Example.MixedCase" "example.missing"]
    remoteExtensions: ["example.remote"]
    cliDirs: (if $server or $no_cli { [] } else { [$env.NU_TEST_STUBS] })
    serverDir: $server_dir
    username: "example-user"
    prune: $prune
  }
  | to json
  | save $config

  let run = with-env {
    PATH: []
    VSCODE_IPC_HOOK_CLI: "/run/user/1000/vscode-ipc-example.sock"
    STUB_LOG: $log
    STUB_LISTING: $listing
    STUB_LISTING_EXIT: ($listing_exit | into string)
    STUB_FAILING_ID: $failing_id
  } {
    (
      ^$nu.current-exe --no-config-file
        $SCRIPT --config $config
      | complete
    )
  }

  {
    run: $run
    changes: (
      open --raw $log
      | from json --objects
      | where ($it.args | first) != "--list-extensions"
      | get args
    )
  }
}

def installs [...ids: string]: nothing -> list<list<string>> {
  $ids | each {|id| ["--install-extension" $id] }
}

def "test only missing extensions are installed, matching IDs case-insensitively" [] {
  let listing = $"($HEADER)example.present\r\nexample.mixedcase\r\nexample.extra\r\n"

  let result = (sync $listing)

  assert equal $result.run {stdout: "" stderr: "" exit_code: 0}
  assert equal $result.changes (installs "example.missing" "example.remote")
}

def "test a CLI inside a Cursor server skips the remote extensions" [] {
  let result = (sync $"($HEADER)example.present\r\n" --server)

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.changes (installs "Example.MixedCase" "example.missing")
}

def "test pruning uninstalls extensions missing from the list" [] {
  let listing = $"($HEADER)example.present\r\nexample.mixedcase\r\nexample.extra\r\n"

  let result = (sync $listing --prune)

  assert equal $result.run {stdout: "" stderr: "" exit_code: 0}
  assert equal $result.changes (
    installs "example.missing" "example.remote"
    | append [["--uninstall-extension" "example.extra"]]
  )
}

def "test a missing CLI skips the sync" [] {
  let result = (sync "" --no-cli)

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert str contains $result.run.stderr "Cursor CLI not found, skipping sync"
  assert equal $result.changes []
}

def "test a failed listing skips the sync" [] {
  let result = (sync "" --prune --listing-exit 1)

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert str contains $result.run.stderr "listing failed, skipping sync: Unable to connect"
  assert equal $result.changes []
}

def "test a failed install warns and the sync continues" [] {
  let result = (sync "" --failing-id "Example.MixedCase")

  assert equal $result.run {
    stdout: "Extension diagnostic: Example.MixedCase\n"
    stderr: "Failed Installing Extensions: Example.MixedCase\nCursor extension install failed for Example.MixedCase, continuing sync\n"
    exit_code: 0
  }
  assert equal $result.changes (
    installs "example.present" "Example.MixedCase" "example.missing" "example.remote"
  )
}
