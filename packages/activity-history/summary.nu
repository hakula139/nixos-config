# ==================================================================================================
# Activity History Summary
# ==================================================================================================

use common.nu *
use context.nu *

const SCRIPT_DIR = path self .

# Long sessions are sampled evenly, keeping the request within the model's context.
const SESSION_EXCERPTS = 40

def sample [count: int]: list -> list {
  let rows = $in
  let n = ($rows | length)
  if $n <= $count {
    return $rows
  }
  0..<$count | each {|i| $rows | get ($i * $n // $count) }
}

def totals-table [metrics: record]: nothing -> string {
  let t = $metrics.totals
  let rows = [
    ["Work, in hours" $t.work_in_hours]
    ["Work, at lunch" $t.work_lunch]
    ["Work, after hours" $t.work_after_hours]
    ["Personal" $t.personal]
    ["Automated (any context)" $t.automated]
    ["Meetings" $t.meetings]
    ["Sum of intervals (parallel sessions in full)" $t.sum]
    ["Wall clock in window (overlaps once)" $t.wall_clock_in_window]
    ["Unattributed in window" $t.unattributed]
  ]
  let body = ($rows | each {|r| $"| ($r.0) | ($r.1 | math round)m |" } | str join "\n")
  ["| Label | Minutes |" "| --- | ---: |" $body] | str join "\n"
}

def recorded-digest [path: string]: nothing -> any {
  if not ($path | path exists) {
    return null
  }
  open --raw $path | parse --regex '<!-- input: (?<d>[0-9a-f]+) -->' | get -o 0.d
}

# Write a day's log unless it was already written from the same request, and report whether it was.
export def summarize [
  cfg: record
  date: string
  metrics: record
  --force # Write even when the request is unchanged
]: nothing -> bool {
  let settings = (settings $cfg)
  let excerpts = (
    read-events $cfg $date
    | where source in $SESSION_SOURCES and kind in [prompt reply]
    | select source session kind ts text
    | group-by --to-table source session
    | each { get items | sort-by ts | sample $SESSION_EXCERPTS }
    | flatten
  )
  let input = {
    metrics: $metrics
    excerpts: $excerpts
    projects: $settings.projects
    examples: $settings.examples
  }
  let prompt = (open --raw ($SCRIPT_DIR | path join prompt.md))
  let request = ([$prompt "" "## Input" "" "```json" ($input | to json) "```"] | str join "\n")
  let digest = ($request | hash sha256)
  let path = (day-path $cfg $date "md")
  if not $force and (recorded-digest $path) == $digest {
    return false
  }

  # User settings carry hooks, such as a Stop gate that would add turns after the log is written.
  # Project settings load from the working directory, and the tree has none.
  let result = do {
    cd $cfg.root
    $request
    | (
      ^$cfg.claude -p
        --output-format json
        --no-session-persistence
        --tools ""
        --strict-mcp-config
        --setting-sources project
    )
    | complete
  }
  if $result.exit_code != 0 {
    error make {msg: $"claude exited with ($result.exit_code): ($result.stderr | str trim)"}
  }
  let reply = ($result.stdout | from json)
  if $reply.stop_reason? == "content_filter" {
    error make {msg: "the content filter stopped the summary. Add the session's path to `ignore`."}
  }
  let body = ($reply.result | str trim)
  if not ($body =~ '(?m)^## Timeline$' and $body =~ '(?m)^## Draft$') {
    let start = ($body | str substring 0..<200)
    error make {msg: $"the summary lacks its `## Timeline` or `## Draft` heading: ($start)"}
  }

  mkdir ($path | path dirname)
  let header = $"# ($date) \(($metrics.weekday)\) - ($cfg.host)"
  [$header "" $"<!-- input: ($digest) -->" "" "## Totals" "" (totals-table $metrics) "" $body ""]
  | str join "\n"
  | save --force $path
  true
}
