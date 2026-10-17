# ==================================================================================================
# Activity History Measurement
# ==================================================================================================

use common.nu *
use context.nu *

# Turns closer together than this belong to one stretch of work.
const JOIN_GAP = 15min
# A turn the agent answered at once still took time to read and follow up on.
const MIN_TURN = 5min

# --------------------------------------------------------------------------------------------------
# Spans
# --------------------------------------------------------------------------------------------------

def overlap [a: record, b: record]: nothing -> duration {
  let start = ([$a.start $b.start] | math max)
  let end = ([$a.end $b.end] | math min)
  if $end > $start { $end - $start } else { 0sec }
}

# Merge spans that overlap or sit within `gap` of each other.
def merge-spans [gap: duration = 0sec]: list -> list {
  sort-by start
  | reduce --fold [] {|span, acc|
    let prev = ($acc | last 1 | get -o 0)
    if $prev != null and $span.start - $prev.end <= $gap {
      $acc | drop 1 | append {start: $prev.start, end: ([$prev.end $span.end] | math max)}
    } else {
      $acc | append {start: $span.start, end: $span.end}
    }
  }
}

def minutes [span: duration]: nothing -> float {
  ($span / 1min) | math round --precision 1
}

def total []: list -> float {
  let values = $in
  if ($values | is-empty) { 0.0 } else { $values | math sum | math round --precision 1 }
}

# --------------------------------------------------------------------------------------------------
# Intervals
# --------------------------------------------------------------------------------------------------

# Join a session's turns, each running from a prompt to its last reply, into stretches of work.
def session-intervals [records: list]: nothing -> list {
  let sorted = ($records | sort-by ts)
  $sorted
  | enumerate
  | where item.kind == "prompt"
  | each {|p|
    let start = (to-local $p.item.ts)
    let after = ($sorted | skip ($p.index + 1))
    let next = ($after | where kind == "prompt" | get -o 0.ts)
    let last = ($after | where {|r| $next == null or $r.ts < $next } | last 1 | get -o 0.ts)
    let end = if $last == null { $start } else { to-local $last }
    {start: $start, end: ([$end ($start + $MIN_TURN)] | math max)}
  }
  | merge-spans $JOIN_GAP
}

# Build the span between two wall-clock durations, such as `12hr`, on the day `bounds` covers.
def clock-span [bounds: record, start: string, end: string]: nothing -> record {
  {start: ($bounds.start + ($start | into duration)), end: ($bounds.start + ($end | into duration))}
}

# Split an interval's minutes across the work window, lunch, and the rest of the day.
def hours-split [cfg: record, bounds: record, interval: record]: nothing -> record {
  let in_window = (overlap $interval (clock-span $bounds $cfg.window.start $cfg.window.end))
  let at_lunch = (overlap $interval (clock-span $bounds $cfg.lunch.start $cfg.lunch.end))
  {
    in: (minutes ($in_window - $at_lunch))
    lunch: (minutes $at_lunch)
    after: (minutes ($interval.end - $interval.start - $in_window))
  }
}

def union-minutes [intervals: list, span: record]: nothing -> float {
  $intervals
  | each {|i| {start: ([$i.start $span.start] | math max), end: ([$i.end $span.end] | math min)} }
  | where {|i| $i.end > $i.start }
  | merge-spans
  | each {|i| minutes ($i.end - $i.start) }
  | total
}

# --------------------------------------------------------------------------------------------------
# Day metrics
# --------------------------------------------------------------------------------------------------

export def measure [cfg: record, date: string]: nothing -> record {
  let settings = (settings $cfg)
  let bounds = (day-bounds $date)
  let weekend = (($bounds.start | format date "%u" | into int) >= 6)
  let events = (read-events $cfg $date)

  let sessions = (
    $events
    | where source in $SESSION_SOURCES
    | insert group {|e| $"($e.source):($e.session)" }
    | group-by --to-table group
    | each {|group|
      let first = ($group.items | first)
      let key = ($first.cwd | path expand --no-symlink)
      if (ignored $settings $key) {
        return []
      }
      let prompts = ($group.items | where kind == "prompt")
      session-intervals $group.items
      | enumerate
      | each {|span|
        {
          id: $"($group.group):($span.index)"
          source: $first.source
          session: $first.session
          project: (project-of $cfg $key)
          key: $key
          mode: $first.mode
          context: (context-of $settings $key $weekend)
          start: $span.item.start
          end: $span.item.end
          title: ($first.title? | default ($prompts | get -o 0.text))
        }
      }
    }
    | flatten
  )

  let meetings = (
    $events
    | where source == "calendar"
    | where {|m| not (ignored $settings $m.key) }
    | each {|m|
      {
        id: $m.id
        source: calendar
        project: meeting
        key: $m.key
        mode: interactive
        context: (context-of $settings $m.key $weekend)
        start: (to-local $m.ts)
        end: (to-local $m.end)
        title: $m.title
      }
    }
  )

  let intervals = (
    $sessions ++ $meetings
    | sort-by start
    | each {|i|
      let concurrent = (
        $i.source != "calendar"
        and ($meetings | any {|m| (overlap $i $m) > 0sec })
      )
      $i | merge {
        minutes: (minutes ($i.end - $i.start))
        hours: (hours-split $cfg $bounds $i)
        concurrent: $concurrent
      }
    }
  )

  let points = (
    $events
    | where source in [git gitlab github]
    | each {|p|
      let key = if $p.key? != null { $p.key } else { $p.cwd | path expand --no-symlink }
      $p | merge {
        project: ($p.project? | default (project-of $cfg $key))
        context: (context-of $settings $key $weekend)
      }
    }
  )

  let window = [
    (clock-span $bounds $cfg.window.start $cfg.lunch.start)
    (clock-span $bounds $cfg.lunch.end $cfg.window.end)
  ]
  let covered = ($window | each {|w| union-minutes $intervals $w } | total)
  let available = ($window | each {|w| minutes ($w.end - $w.start) } | total)

  let sum_by = {|rows: list, field: string| $rows | each {|r| $r.hours | get $field } | total }
  let work = ($intervals | where context == "work")
  {
    date: $date
    host: $cfg.host
    weekday: ($bounds.start | format date "%a")
    weekend: $weekend
    totals: {
      work_in_hours: (do $sum_by $work "in")
      work_lunch: (do $sum_by $work "lunch")
      work_after_hours: (do $sum_by $work "after")
      personal: ($intervals | where context == "personal" | get -o minutes | total)
      automated: ($intervals | where mode == "automated" | get -o minutes | total)
      meetings: ($meetings | each {|m| minutes ($m.end - $m.start) } | total)
      sum: ($intervals | get -o minutes | total)
      wall_clock_in_window: $covered
      unattributed: (if $weekend { 0.0 } else { [($available - $covered) 0.0] | math max })
    }
    intervals: (
      $intervals
      | each {|i| $i | update start { format date "%H:%M" } | update end { format date "%H:%M" } }
    )
    points: $points
  }
}
