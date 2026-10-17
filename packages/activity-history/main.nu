#!/usr/bin/env nu

# ==================================================================================================
# Activity History
# ==================================================================================================
# Records each day's agent sessions, commits, forge activity, and meetings as events, measures the
# time they cover, and has Claude Code write a readable log into this host's history tree.
# ==================================================================================================

use common.nu *
use metrics.nu *
use sessions.nu *
use sources.nu *
use summary.nu *

# Runs after midnight still see late work, so the previous day is always collected again.
const REFRESH_DAYS = 2
const BACKFILL_DAYS = 7

# --------------------------------------------------------------------------------------------------
# Pipeline
# --------------------------------------------------------------------------------------------------

def fail [msg: string]: nothing -> nothing {
  print --stderr $"activity-history: ($msg)"
  exit 1
}

def config []: nothing -> record {
  let path = $env.ACTIVITY_HISTORY_CONFIG?
  if $path == null {
    fail "ACTIVITY_HISTORY_CONFIG is unset. Run the installed activity-history command."
  }
  open $path
}

def today []: nothing -> string {
  date now | format date "%Y-%m-%d"
}

# Day paths are built from the date string, so any other shape would land in the wrong directory.
def day-arg [date?: string]: nothing -> string {
  if $date == null {
    return (today)
  }
  if not ($date =~ '^\d{4}-\d{2}-\d{2}$') {
    fail $"expected a date as YYYY-MM-DD, got '($date)'"
  }
  $date
}

# Collect each source, returning those that failed, which keep their previous events.
def collect [cfg: record, date: string]: nothing -> list<string> {
  let bounds = (day-bounds $date)
  let dir = (events-dir $cfg $date)
  $cfg.sources | each {|source|
    try {
      let rows = match $source {
        "claude" => (collect-claude $cfg $bounds)
        "codex" => (collect-codex $cfg $bounds)
        "omp" => (collect-omp $cfg $bounds)
        "git" => (collect-git $cfg $bounds)
        "gitlab" => (collect-gitlab $cfg $bounds)
        "github" => (collect-github $cfg $bounds)
        "calendar" => (collect-calendar $cfg $date)
      }
      write-jsonl ($dir | path join $"($source).jsonl") ($rows | sort-by ts id)
      null
    } catch {|e|
      print --stderr $"activity-history: ($date): ($source) failed: (error-text $e)"
      $source
    }
  }
  | compact
}

# The calendar syncs once per run, ahead of the days that read it.
def sync-sources [cfg: record]: nothing -> nothing {
  if "calendar" in $cfg.sources {
    try {
      sync-calendar
    } catch {|e|
      print --stderr $"activity-history: calendar sync failed: (error-text $e)"
    }
  }
}

# Record a day, returning the sources that failed to collect.
def process [cfg: record, date: string]: nothing -> list<string> {
  let failed = (collect $cfg $date)
  let metrics = (measure $cfg $date)
  let metrics_path = (day-path $cfg $date "metrics.json")
  mkdir ($metrics_path | path dirname)
  $metrics | insert failed_sources $failed | to json | save --force $metrics_path
  if (summarize $cfg $date $metrics) {
    print $"($date): wrote (day-path $cfg $date "md")"
  } else {
    print $"($date): input unchanged, kept the log"
  }
  $failed
}

def ensure-tree [cfg: record]: nothing -> nothing {
  if not ($cfg.root | path join ".git" | path exists) {
    mkdir $cfg.root
    ^git -C $cfg.root init --quiet
  }
}

def commit [cfg: record, dates: list<string>]: nothing -> nothing {
  ^git -C $cfg.root add --all
  let staged = (^git -C $cfg.root diff --cached --quiet | complete)
  if $staged.exit_code != 0 {
    ^git -C $cfg.root commit --quiet --message $"chore: record ($dates | str join ', ')"
  }
}

def incomplete [cfg: record, date: string]: nothing -> bool {
  let metrics = (day-path $cfg $date "metrics.json")
  if not ((day-path $cfg $date "md" | path exists) and ($metrics | path exists)) {
    return true
  }
  open $metrics | get -o failed_sources | is-not-empty
}

def dates-to-run [cfg: record]: nothing -> list<string> {
  let today = (today | into datetime)
  0..<$BACKFILL_DAYS
  | each {|n| $today - ($n * 1day) | format date "%Y-%m-%d" }
  | enumerate
  | where {|d| $d.index < $REFRESH_DAYS or (incomplete $cfg $d.item) }
  | get item
  | reverse
}

# --------------------------------------------------------------------------------------------------
# Subcommands
# --------------------------------------------------------------------------------------------------

# Collect, measure, summarize, and commit recent days.
#
# Without a date, runs today, yesterday, and any of the last week's days that lack a log or failed
# to collect a source, so later runs retry them. A day keeps its log while the summary's input is
# unchanged.
def "main run" [
  date?: string # Only this local date, as YYYY-MM-DD
]: nothing -> nothing {
  let cfg = (config)
  ensure-tree $cfg
  sync-sources $cfg
  let dates = if $date != null { [(day-arg $date)] } else { dates-to-run $cfg }
  let failed = (
    $dates
    | each {|d|
      try {
        if (process $cfg $d | is-not-empty) { $d }
      } catch {|e|
        print --stderr $"activity-history: ($d): (error-text $e)"
        $d
      }
    }
    | compact
  )
  commit $cfg $dates
  if ($failed | is-not-empty) {
    fail $"incomplete: ($failed | str join ', ')"
  }
}

# Fetch one day's events into events/, without measuring, summarizing, or committing.
def "main collect" [
  date?: string # Local date as YYYY-MM-DD, today by default
]: nothing -> nothing {
  let cfg = (config)
  let date = (day-arg $date)
  sync-sources $cfg
  collect $cfg $date | ignore
  print (events-dir $cfg $date)
}

# Print one day's intervals and totals as JSON, computed from collected events.
def "main measure" [
  date?: string # Local date as YYYY-MM-DD, today by default
]: nothing -> nothing {
  measure (config) (day-arg $date) | to json | print
}

# Rewrite one day's log from its collected events, without collecting or committing.
def "main summarize" [
  date?: string # Local date as YYYY-MM-DD, today by default
]: nothing -> nothing {
  let cfg = (config)
  let date = (day-arg $date)
  summarize $cfg $date (measure $cfg $date) --force | ignore
  print (day-path $cfg $date "md")
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Record each day's agent sessions, commits, forge activity, and meetings in a daily log.
#
# The tree at the config's root holds events/YYYY/YYYY-MM-DD/<source>.jsonl, then
# days/YYYY/YYYY-MM-DD.metrics.json and days/YYYY/YYYY-MM-DD.md. Each host can extend the context
# rules, ignore patterns, project names, and phrasing examples in
# ~/.config/activity-history/config.toml.
def main []: nothing -> nothing {
  help main
}
