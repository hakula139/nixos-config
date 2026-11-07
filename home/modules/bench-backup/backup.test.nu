#!/usr/bin/env nu

# ==================================================================================================
# Private Bench Backup Tests
# ==================================================================================================

use std/assert
use ./backup.nu snapshot-votes

const SCRIPT = path self "backup.nu"

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
  let python = '
import os
import sqlite3
import subprocess
import sys

database = os.path.join(os.environ["DATABASE_DIR"], "votes.sqlite")
with sqlite3.connect(database) as source:
    source.execute("PRAGMA journal_mode=WAL")
    source.execute("PRAGMA wal_autocheckpoint=0")
    source.execute("CREATE TABLE votes (value TEXT)")
    source.execute("INSERT INTO votes VALUES (?)", ("committed vote",))
    source.commit()
    assert os.path.getsize(database + "-wal") > 0
    subprocess.run([sys.argv[1], "--no-config-file", "-c", sys.argv[2]], check=True)
    target = os.path.join(os.environ["SNAPSHOT"], "local-votes.sqlite")
    assert os.stat(target).st_mode & 0o777 == 0o600
    with sqlite3.connect(target) as snapshot:
        assert snapshot.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        assert snapshot.execute("SELECT value FROM votes").fetchall() == [("committed vote",)]
    assert source.execute("SELECT count(*) FROM votes").fetchone() == (1,)
'

  with-env {DATA: $paths.root, DATABASE_DIR: $paths.database_dir, SNAPSHOT: $paths.snapshot_dir} {
    let result = (^python3 -c $python $nu.current-exe $code | complete)

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
  let config = ($paths.root | path join "config.json")
  {dataDir: $paths.root, restic: $nu.current-exe} | to json | save $config

  let result = (^$nu.current-exe --no-config-file $SCRIPT backup --config $config | complete)

  assert not equal $result.exit_code 0
  assert (not ($paths.root | path join ".backup-snapshot" | path exists))
}
