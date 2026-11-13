#!/usr/bin/env nu

# ==================================================================================================
# Claude Code Status Line Command
# ==================================================================================================
# Row 1: <directory> <git>
# Row 2: Model | Ctx: X% (XXk/1000k) | Sess: $X.XX | Block: $X.XX (XhYm left, $X.XX/h)
#        | Today: $X.XX | HH:MM
# ==================================================================================================

const SCRIPT_PATH = path self

const CCUSAGE_CACHE = $nu.cache-dir | path join "claude-code/statusline-usage.json"
const CCUSAGE_TTL = 30sec
const CCUSAGE_MAX_STALE = 10min
const CCUSAGE_LOCK_NAME = "statusline-usage.lock"
const CCUSAGE_FIELDS = [
  "date"
  "has_block"
  "has_daily"
  "block_cost"
  "remaining_minutes"
  "burn_rate"
  "daily_cost"
]

# --------------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------------

def dim [text: string]: nothing -> string {
  $"(ansi white_dimmed)($text)(ansi reset)"
}

def paint [text: string, color: string]: nothing -> string {
  $"(ansi $color)($text)(ansi reset)"
}

def labeled [label: string, value: string, color: string = "green"]: nothing -> string {
  $"(dim ($label + ":")) (paint $value $color)"
}

def usd [amount: float]: nothing -> string {
  if $amount == 0 {
    "$0.00"
  } else {
    $"$($amount | into string --decimals 2)"
  }
}

# --------------------------------------------------------------------------------------------------
# Git info
# --------------------------------------------------------------------------------------------------

const NO_BRANCH = {branch: "", ahead: 0, behind: 0}

def git-status [cwd: string]: nothing -> list<string> {
  let result = (
    ^git
      -C $cwd
      --no-optional-locks
      status
        --porcelain
        --branch
    | complete
  )
  if $result.exit_code != 0 {
    return []
  }

  $result.stdout | lines
}

def track-count [track: string, label: string]: nothing -> int {
  $track | parse --regex ($label + ' (?<n>\d+)') | get -o 0.n | default "0" | into int
}

# `## <branch>...<upstream> [ahead N, behind M]`, where everything after the branch is optional. A
# detached HEAD reads `## HEAD (no branch)` and an unborn one `## No commits yet on <branch>`.
def parse-branch [header: string]: nothing -> record<branch: string, ahead: int, behind: int> {
  if $header == "## HEAD (no branch)" {
    return $NO_BRANCH
  }

  let parsed = (
    $header
    | parse --regex '^## (?:No commits yet on )?(?<branch>\S+?)(?:\.\.\.\S*)?(?: \[(?<track>[^\]]*)\])?$'
    | get -o 0
  )
  if $parsed == null {
    return $NO_BRANCH
  }

  {
    branch: $parsed.branch
    ahead: (track-count ($parsed.track | default "") "ahead")
    behind: (track-count ($parsed.track | default "") "behind")
  }
}

# Porcelain v1 XY codes: X is the index status, Y the worktree status.
def work-counts [
  entries: list<string>
]: nothing -> record<staged: int, modified: int, untracked: int> {
  let codes = ($entries | each { str substring 0..<2 })
  {
    staged: ($codes | where ($it | str substring 0..<1) in ["M", "A"] | length)
    modified: ($codes | where $it == " M" | length)
    untracked: ($codes | where $it == "??" | length)
  }
}

def format-git-info [cwd: string]: nothing -> string {
  let output = (git-status $cwd)
  let branch = (parse-branch ($output | first | default ""))
  if ($branch.branch | is-empty) {
    return ""
  }

  let work = (work-counts ($output | skip 1))
  let marks = (
    [
      {symbol: "»", n: $branch.ahead}
      {symbol: "«", n: $branch.behind}
      {symbol: "+", n: $work.staged}
      {symbol: "!", n: $work.modified}
      {symbol: "?", n: $work.untracked}
    ]
    | where n > 0
    | each {|mark| $" ($mark.symbol)($mark.n)" }
    | str join
  )

  $" (paint $branch.branch green)(paint $marks yellow) "
}

# --------------------------------------------------------------------------------------------------
# Model name
# --------------------------------------------------------------------------------------------------

def model-name [input: record, models: record]: nothing -> string {
  let id = ($input.model?.id? | default "")
  # Claude's model ID can carry a context-window suffix.
  let model_id = ($id | str replace --regex '(?i)\[1m\]$' "")
  let display_name = ($input.model?.display_name? | default $id | str trim)
  let fallback = if $display_name == $id {
    $model_id | split row "/" | last
  } else {
    $display_name | str replace "(1M context)" "(1M)"
  }
  let name = ($models | get -o $model_id | default $fallback)
  if ($name | is-empty) {
    return ""
  }

  let large_context = (
    ($input.context_window?.context_window_size? | default 0) >= 1000000
    or ($id | str lowercase | str ends-with "[1m]")
  )
  [
    $name
    (if $large_context and not ($name | str contains "(1M)") { "(1M)" })
    $input.effort?.level?
  ]
  | compact --empty
  | str join " "
}

# --------------------------------------------------------------------------------------------------
# Context and session (from Claude Code JSON)
# --------------------------------------------------------------------------------------------------

def format-claude-info [input: record]: nothing -> record<ctx: string, sess: string> {
  let usage = ($input.context_window?.current_usage? | default {})
  let used = (
    ["input_tokens" "cache_creation_input_tokens" "cache_read_input_tokens"]
    | each {|key| $usage | get -o $key | default 0 }
    | math sum
  )
  let size = ($input.context_window?.context_window_size? | default 0)

  let ctx = if $size == 0 {
    labeled "Ctx" "0%"
  } else {
    let percent = ($used * 100 // $size)
    let color = if $percent >= 80 { "red" } else if $percent >= 50 { "yellow" } else { "green" }
    labeled "Ctx" $"($percent)% \(($used // 1000)k/($size // 1000)k)" $color
  }

  {
    ctx: $ctx
    sess: (labeled "Sess" (usd ($input.cost?.total_cost_usd? | default 0 | into float)))
  }
}

# --------------------------------------------------------------------------------------------------
# ccusage integration
# --------------------------------------------------------------------------------------------------

def modified-time [path: path]: nothing -> datetime {
  let expanded = ($path | path expand)
  ls ($expanded | path dirname) | where name == $expanded | get 0.modified
}

# A fresh TTL alone would still accept a payload written by an older schema.
def cache-valid [cached: any]: nothing -> bool {
  (
    ($cached | describe | str starts-with "record")
    and ($CCUSAGE_FIELDS | all {|field| $field in $cached })
    and ($cached.date == (date now | format date "%Y%m%d"))
  )
}

def read-cache [cache: path, max_age: duration]: nothing -> record {
  let cached = (try {
    if not ($cache | path exists) {
      null
    } else if ((date now) - (modified-time $cache)) >= $max_age {
      null
    } else {
      open $cache
    }
  } catch {
    null
  })
  if ($cached != null and (cache-valid $cached)) {
    $cached
  } else {
    {}
  }
}

def ccusage-json [args: list<string>]: nothing -> record {
  let result = (
    ^ccusage claude ...$args
      --json
      --offline
    | complete
  )
  if $result.exit_code != 0 {
    error make {msg: $"ccusage ($args | str join ' ') exited ($result.exit_code)"}
  }
  let parsed = (
    try {
      $result.stdout | from json
    } catch {
      error make {msg: $"ccusage ($args | str join ' ') returned invalid JSON"}
    }
  )
  if not ($parsed | describe | str starts-with "record") {
    error make {msg: $"ccusage ($args | str join ' ') returned invalid JSON"}
  }
  $parsed
}

def current-usage []: nothing -> record {
  let today = (date now | format date "%Y%m%d")
  let blocks = (ccusage-json [blocks --active])
  let active = ($blocks.blocks? | default [] | where ($it.isActive? | default false) | get -o 0)
  let daily = (ccusage-json [
    daily
      --since $today
      --until $today
  ])
  let daily_cost = $daily.totals?.totalCost?

  {
    date: $today
    has_block: ($active != null)
    has_daily: ($daily_cost != null)
    block_cost: ($active.costUSD? | default 0 | into float)
    remaining_minutes: ($active.projection?.remainingMinutes? | default 0 | math floor)
    burn_rate: ($active.burnRate?.costPerHour? | default 0 | into float)
    daily_cost: ($daily_cost | default 0 | into float)
  }
}

# Contenders must lock the same inode, so the lock file stays allocated and is never deleted.
def lock-path [cache: path]: nothing -> path {
  ($cache | path dirname) | path join $CCUSAGE_LOCK_NAME
}

def temp-cache-path [cache: path]: nothing -> path {
  $"($cache).($nu.pid).tmp"
}

def write-cache [cache: path, data: record]: nothing -> nothing {
  let tmp = (temp-cache-path $cache)
  try {
    $data | to json | save --force --raw $tmp
  } catch {
    ^rm -f $tmp | complete | ignore
    error make {msg: "failed to write usage cache"}
  }

  let moved = (^mv --force $tmp $cache | complete)
  if $moved.exit_code != 0 {
    ^rm -f $tmp | complete | ignore
    error make {msg: "failed to publish usage cache"}
  }
}

def refresh-cache [cache: path, lock: path]: nothing -> record {
  let result = (
    ^flock --nonblock $lock $nu.current-exe $SCRIPT_PATH --cache $cache --refresh-usage
    | complete
  )
  if $result.exit_code == 0 {
    read-cache $cache $CCUSAGE_TTL
  } else {
    read-cache $cache $CCUSAGE_MAX_STALE
  }
}

def read-ccusage [cache: path]: nothing -> record {
  let cached = (read-cache $cache $CCUSAGE_TTL)
  if ($cached | is-not-empty) {
    return $cached
  }

  ^mkdir -p ($cache | path dirname) | complete | ignore
  refresh-cache $cache (lock-path $cache)
}

def format-remaining [minutes: int]: nothing -> string {
  if $minutes <= 0 {
    return ""
  }
  let hours = ($minutes // 60)
  if $hours > 0 {
    $"($hours)h($minutes mod 60)m left"
  } else {
    $"($minutes)m left"
  }
}

def format-ccusage-info [data: record]: nothing -> record<block: string, daily: string> {
  let remaining = ($data.remaining_minutes? | default 0)
  let burn_rate = ($data.burn_rate? | default 0.0)
  let details = (
    [
      (format-remaining $remaining)
      (if $burn_rate > 0 { $"(usd $burn_rate)/h" })
    ]
    | compact --empty
    | str join ", "
  )
  let suffix = if ($details | is-empty) {
    ""
  } else {
    " " + (paint $"\(($details)\)" yellow)
  }

  {
    block: (if ($data.has_block? | default false) {
      $"(labeled "Block" (usd ($data.block_cost? | default 0.0)) cyan)($suffix)"
    } else {
      ""
    })
    daily: (if ($data.has_daily? | default false) {
      labeled "Today" (usd ($data.daily_cost? | default 0.0)) cyan
    } else {
      ""
    })
  }
}

# --------------------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------------------

def main [
  --config: path # Wrapper-supplied JSON with the display name of each model ID
  --cache: path = $CCUSAGE_CACHE # Usage cache shared by concurrent status lines
  --refresh-usage # Writes the usage cache and exits
] {
  if $refresh_usage {
    write-cache $cache (current-usage)
    return
  }

  let config = (open $config)
  # `open /dev/stdin` re-opens fd 0 by path, which fails with ENXIO when the caller passes a socket
  # instead of a pipe, as Claude Code's spawn does.
  let input = (^cat | from json)
  let cwd = $input.workspace.current_dir

  let dir_name = if $cwd == $nu.home-dir {
    "~"
  } else {
    $cwd | path basename
  }
  let row1 = $"(paint $dir_name blue_bold)(format-git-info $cwd)"

  let model = (model-name $input $config.models)
  let claude = (format-claude-info $input)
  let ccusage = (format-ccusage-info (read-ccusage $cache))

  let row2 = (
    [
      (if ($model | is-not-empty) { paint $model cyan })
      $claude.ctx
      $claude.sess
      $ccusage.block
      $ccusage.daily
      (dim (date now | format date "%H:%M"))
    ]
    | compact --empty
    | str join $" (dim "|") "
  )

  print --no-newline $"($row1)\n($row2)"
}
