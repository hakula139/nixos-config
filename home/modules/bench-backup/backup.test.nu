#!/usr/bin/env nu

# ==================================================================================================
# Private Bench Backup Tests
# ==================================================================================================

use std/assert
use ./backup.nu snapshot-votes

const SCRIPT = path self "backup.nu"
const WAL_FIXTURE = path self "wal-fixture.py"

def fixture [] {
  let root = (mktemp -d)
  let database_dir = ($root | path join "arena/v3/d1/miniflare-D1DatabaseObject")
  let snapshot_dir = ($root | path join "snapshot's directory")
  mkdir $database_dir $snapshot_dir
  {root: $root, database_dir: $database_dir, snapshot_dir: $snapshot_dir}
}

def "test snapshot includes committed WAL data without touching the live database" [] {
  let paths = (fixture)
  let code = $"use ($SCRIPT | to nuon) snapshot-votes; snapshot-votes $env.DATA $env.SNAPSHOT"

  with-env {DATA: $paths.root, DATABASE_DIR: $paths.database_dir, SNAPSHOT: $paths.snapshot_dir} {
    let result = (^python3 $WAL_FIXTURE $nu.current-exe $code | complete)

    assert equal $result.exit_code 0 $result.stderr
  }
}

def "test metadata is ignored and ambiguous vote databases fail" [] {
  let paths = (fixture)
  touch ($paths.database_dir | path join "metadata.sqlite")

  snapshot-votes $paths.root $paths.snapshot_dir

  assert equal (ls $paths.snapshot_dir | length) 0

  touch ($paths.database_dir | path join "first.sqlite")
  touch ($paths.database_dir | path join "second.sqlite")

  let result = (try {
    snapshot-votes $paths.root $paths.snapshot_dir
    false
  } catch {
    true
  })

  assert $result
}

def "test failed repository backup removes the SQLite snapshot" [] {
  let paths = (fixture)
  let database = ($paths.database_dir | path join "votes.sqlite")
  ^sqlite3 $database "CREATE TABLE votes (value TEXT);"
  let restic = ($paths.root | path join "restic")
  $"#!($nu.current-exe)\nprint --stderr 'synthetic-private-marker'\nexit 12\n" | save $restic
  ^chmod +x $restic
  let config = ($paths.root | path join "config.json")
  {dataDir: $paths.root, restic: $restic} | to json | save $config

  let result = (^$nu.current-exe --no-config-file $SCRIPT backup --config $config | complete)

  assert not equal $result.exit_code 0
  assert (not ($paths.root | path join ".backup-snapshot" | path exists))
  assert ($result.stderr | str contains "Restic backup failed (exit 12)")
  assert ($result.stderr | str contains "Repository password is incorrect")
  assert (not ($result.stderr | str contains "synthetic-private-marker"))
}

def "test backup keeps keys and vote snapshot without Miniflare runtime state" [] {
  let paths = (fixture)
  let database = ($paths.database_dir | path join "votes.sqlite")
  ^sqlite3 $database "CREATE TABLE votes (value TEXT); INSERT INTO votes VALUES ('sample');"
  let cache = ($paths.root | path join "arena/v3/cache")
  mkdir $cache
  ^sqlite3 ($cache | path join "metadata.sqlite") "CREATE TABLE cache (value TEXT);"
  "private key fixture" | save ($paths.root | path join "arena/keys.json")
  let config = ($paths.root | path join "config.json")
  let restic = (
    which restic
    | first
    | get path
  )
  {dataDir: $paths.root, restic: $restic}
  | to json
  | save $config
  let repository = (mktemp -d)

  with-env {
    RESTIC_REPOSITORY: $repository
    RESTIC_PASSWORD: "fixture-password"
    RESTIC_CACHE_DIR: (mktemp -d)
  } {
    ^restic init --quiet
    let result = (
      ^$nu.current-exe
        --no-config-file
        $SCRIPT backup
          --config $config
      | complete
    )
    assert equal $result.exit_code 0 $result.stderr

    let files = (
      ^restic ls latest --json
      | from json --objects
      | where {|row| ($row | get -o struct_type) == "node" }
      | get path)
    assert ($files | any {|file| $file | str ends-with "/arena/keys.json" })
    assert ($files | any {|file| $file | str ends-with "/.backup-snapshot/local-votes.sqlite" })
    assert (not ($files | any {|file| $file | str contains "/arena/v3" }))
  }
}
