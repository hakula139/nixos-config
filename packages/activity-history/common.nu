# ==================================================================================================
# Activity History Shared Helpers
# ==================================================================================================

const EXCERPT_CHARS = 400

export const SESSION_SOURCES = [claude codex omp]

# --------------------------------------------------------------------------------------------------
# Time
# --------------------------------------------------------------------------------------------------

export def day-bounds [date: string]: nothing -> record {
  let start = ($date | into datetime)
  {start: $start, end: ($start + 1day)}
}

export def utc-iso [time: datetime]: nothing -> string {
  $time | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%S.000Z"
}

export def to-local [ts: string]: nothing -> datetime {
  $ts | into datetime | date to-timezone local
}

export def within [bounds: record]: any -> bool {
  let value = $in
  $value != null and $value >= $bounds.start and $value < $bounds.end
}

# --------------------------------------------------------------------------------------------------
# Files
# --------------------------------------------------------------------------------------------------

export def events-dir [cfg: record, date: string]: nothing -> string {
  $cfg.root | path join "events" ($date | str substring 0..3) $date
}

export def day-path [cfg: record, date: string, ext: string]: nothing -> string {
  $cfg.root | path join "days" ($date | str substring 0..3) $"($date).($ext)"
}

export def read-events [cfg: record, date: string]: nothing -> list {
  glob $"(events-dir $cfg $date)/*.jsonl"
  | sort
  | each { open --raw $in | from json --objects }
  | flatten
}

export def write-jsonl [path: string, rows: list]: nothing -> nothing {
  mkdir ($path | path dirname)
  $rows | each { to json --raw } | str join "\n" | save --force $path
}

# --------------------------------------------------------------------------------------------------
# Text
# --------------------------------------------------------------------------------------------------

export def excerpt []: any -> any {
  let text = $in
  if ($text | is-empty) {
    return null
  }
  let flat = ($text | str replace --all --regex '\s+' ' ' | str trim)
  if ($flat | str length) > $EXCERPT_CHARS {
    ($flat | str substring 0..<$EXCERPT_CHARS) + "..."
  } else {
    $flat
  }
}

# --------------------------------------------------------------------------------------------------
# Errors
# --------------------------------------------------------------------------------------------------

# Append the label, which names the missing command where the message only says an external failed.
export def error-text [e: record]: nothing -> string {
  let label = ($e.json | from json | get -o labels.0.text)
  if ($label | is-empty) or $label == $e.msg { $e.msg } else { $"($e.msg): ($label)" }
}
