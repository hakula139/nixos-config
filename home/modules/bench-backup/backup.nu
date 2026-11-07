#!/usr/bin/env nu

# ==================================================================================================
# Private Bench Backup
# ==================================================================================================

def restic [command: string, args: list<string>] {
  let result = (run-external $command ...$args | complete)
  if $result.exit_code != 0 {
    let diagnosis = match $result.exit_code {
      2 => "Go runtime error"
      3 => {
        if $args.0 == "backup" { "Some source data could not be read" } else {
          "One or more snapshots could not be removed"
        }
      }
      10 => "Repository does not exist. Initialize it with restic-bench init"
      11 => "Could not lock the repository"
      12 => "Repository password is incorrect"
      130 => "Operation was cancelled"
      _ => "Run restic-bench interactively for details"
    }
    error make {msg: $"Restic ($args.0) failed \(exit ($result.exit_code)\): ($diagnosis)"}
  }
}

# Make a consistent snapshot of the unique local voting database.
export def snapshot-votes [data_dir: path, snapshot_dir: path] {
  let database_dir = ($data_dir | path join "arena/v3/d1/miniflare-D1DatabaseObject")
  let databases = if ($database_dir | path exists) {
    glob ($database_dir | path join "*.sqlite")
    | where {|file| ($file | path basename) != "metadata.sqlite" }
  } else {
    []
  }

  if ($databases | length) > 1 {
    error make {msg: "Expected a unique local voting database"}
  }
  if ($databases | is-empty) {
    return
  }

  let destination = ($snapshot_dir | path join "local-votes.sqlite")
  let quoted = ($destination | str replace --all "'" "''")
  let snapshot = (^sqlite3 -readonly -cmd ".timeout 30000" ($databases | first)
    $"VACUUM INTO '($quoted)';" | complete)
  if $snapshot.exit_code != 0 {
    error make {msg: "Could not snapshot the local voting database"}
  }
  ^chmod 0600 $destination

  let integrity = (^sqlite3 -readonly $destination "PRAGMA integrity_check;" | complete)
  if $integrity.exit_code != 0 or ($integrity.stdout | str trim) != "ok" {
    error make {msg: "Local voting database snapshot failed its integrity check"}
  }
}

# Back up private bench data or maintain its encrypted repository.
def main [
  mode: string # Operation: backup or maintain
  --config: path # Packaged configuration
] {
  let config = (open $config)

  if $mode == "maintain" {
    restic $config.restic [forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune]
    restic $config.restic [check --read-data]
    print "Repository retention and full data check completed."
    return
  }
  if $mode != "backup" {
    error make {msg: "Operation must be backup or maintain"}
  }
  if not ($config.dataDir | path exists) {
    error make {msg: "Private bench data directory does not exist"}
  }

  let snapshot_dir = ($config.dataDir | path join ".backup-snapshot")
  rm --recursive --force $snapshot_dir
  ^install -dm0700 $snapshot_dir

  try {
    snapshot-votes $config.dataDir $snapshot_dir
    cd $config.dataDir
    restic $config.restic [backup --quiet --exclude ./checks --exclude ./agents
      --exclude ./arena/v3/d1 --exclude "*.lock" --exclude "*.sqlite-wal"
      --exclude "*.sqlite-shm" .]
  } catch {|failure|
    rm --recursive --force $snapshot_dir
    error make {msg: $failure.msg}
  }

  rm --recursive --force $snapshot_dir
  print "Private bench backup completed."
}
