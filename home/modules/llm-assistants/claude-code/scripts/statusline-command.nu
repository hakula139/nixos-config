#!/usr/bin/env nu

# ==============================================================================
# Claude Code Status Line Command
# ==============================================================================
# Row 1: #tty <directory> <git>
# Row 2: Model | Ctx: X% (XXk/200k) | Sess: $X.XX | Block: $X.XX (XhYm left, $X.XX/h) | Today: $X.XX | HH:MM
# ==============================================================================

const NPX = "@npx@"
const GET_TTY_NUM = "@getTtyNum@"

const CCUSAGE_CACHE = "/tmp/ccusage-statusline.json"
const CCUSAGE_TTL = 30sec
const CCUSAGE_FIELDS = [has_data, block_cost, remaining_minutes, burn_rate, daily_cost]

# Cached like any result, so a failed lookup does not respawn npx every render.
const NO_BLOCK = {
  has_data: false
  block_cost: 0.0
  remaining_minutes: 0
  burn_rate: 0.0
  daily_cost: 0.0
}

const MODEL_FAMILIES = [
  [pattern, name];
  ["opus", "Opus"]
  ["sonnet", "Sonnet"]
  ["haiku", "Haiku"]
  ["gpt", "GPT"]
]

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def dim [text: string]: nothing -> string {
  $"(ansi white_dimmed)($text)(ansi reset)"
}

def paint [text: string, color: string]: nothing -> string {
  $"(ansi $color)($text)(ansi reset)"
}

def labeled [label: string, value: string, color: string = "green"]: nothing -> string {
  $"(dim ($label + ':')) (paint $value $color)"
}

def usd [amount: float]: nothing -> string {
  $"$($amount | into string --decimals 2)"
}

# ------------------------------------------------------------------------------
# Model name
# ------------------------------------------------------------------------------

# Input may be a display name ("Opus 4.6 (1M context)"), a Bedrock raw ID
# ("global.anthropic.claude-opus-4-6-v1[1m]"), or a corp-gateway override
# ("openai/gpt-5.4-mini").
def simplify-model-name [raw: string]: nothing -> string {
  let lc = ($raw | str downcase)
  let family = (
    $MODEL_FAMILIES | where ($lc | str contains $it.pattern) | get -o 0.name
  )
  if $family == null { return $raw }

  let version = (
    $lc
    | parse --regex `(?:opus|sonnet|haiku|gpt)[- ](?<v>\d+(?:[-.]\d+)?)`
    | get -o 0.v
    | default ""
    | str replace --all "-" "."
  )

  [
    $family
    $version
    (if ($lc | str contains "mini") { "mini" })
    (if ($lc | str contains "1m") { "(1M)" })
  ]
  | compact --empty
  | str join " "
}

# ------------------------------------------------------------------------------
# Git info
# ------------------------------------------------------------------------------

# A rest param would claim `--flag` as our own, hence the list. Trimming stays
# right-side only because a porcelain status code leads with a significant space.
def git-porcelain [cwd: string, args: list<string>]: nothing -> string {
  let result = (^git -C $cwd --no-optional-locks ...$args | complete)
  if $result.exit_code == 0 { $result.stdout | str trim --right } else { "" }
}

def divergence [cwd: string]: nothing -> record<behind: int, ahead: int> {
  git-porcelain $cwd [rev-list --left-right --count "@{upstream}...HEAD"]
  | parse --regex `(?<behind>\d+)\s+(?<ahead>\d+)`
  | get -o 0
  | default { behind: "0", ahead: "0" }
  | into int behind ahead
}

# Porcelain v1 XY codes: X is the index status, Y the worktree status.
def work-counts [cwd: string]: nothing -> record<staged: int, modified: int, untracked: int> {
  let codes = (
    git-porcelain $cwd [status --porcelain] | lines | each { str substring 0..<2 }
  )
  {
    staged: ($codes | where ($it | str substring 0..<1) in ["M", "A"] | length)
    modified: ($codes | where $it == " M" | length)
    untracked: ($codes | where $it == "??" | length)
  }
}

def format-git-info [cwd: string]: nothing -> string {
  let branch = (git-porcelain $cwd [branch --show-current])
  if ($branch | is-empty) { return "" }

  let counts = ((divergence $cwd) | merge (work-counts $cwd))
  let marks = (
    [
      ["»", $counts.ahead]
      ["«", $counts.behind]
      ["+", $counts.staged]
      ["!", $counts.modified]
      ["?", $counts.untracked]
    ]
    | where $it.1 > 0
    | each {|mark| $" ($mark.0)($mark.1)" }
    | str join
  )

  $" (paint $branch "green")(paint $marks "yellow") "
}

# ------------------------------------------------------------------------------
# Context and session (from Claude Code JSON)
# ------------------------------------------------------------------------------

def format-claude-info [input: record]: nothing -> record<ctx: string, sess: string> {
  let usage = ($input.context_window?.current_usage? | default {})
  let used = (
    [input_tokens cache_creation_input_tokens cache_read_input_tokens]
    | each {|key| $usage | get -o $key | default 0 }
    | math sum
  )
  let size = ($input.context_window?.context_window_size? | default 0)

  let ctx = if $size == 0 { labeled "Ctx" "0%" } else {
    let percent = ($used * 100 // $size)
    let color = if $percent >= 80 { "red" } else if $percent >= 50 { "yellow" } else { "green" }
    labeled "Ctx" $"($percent)% \(($used // 1000)k/($size // 1000)k)" $color
  }

  {
    ctx: $ctx
    sess: (labeled "Sess" (usd ($input.cost?.total_cost_usd? | default 0 | into float)))
  }
}

# ------------------------------------------------------------------------------
# ccusage integration
# ------------------------------------------------------------------------------

def cache-is-fresh []: nothing -> bool {
  try { (date now) - (ls $CCUSAGE_CACHE | get 0.modified) < $CCUSAGE_TTL } catch { false }
}

# The TTL alone would accept a payload written by an older schema. `open` on an
# empty file yields null rather than raising, and `in` raises on a non-record.
def read-cache []: nothing -> record {
  if not (cache-is-fresh) { return {} }
  let cached = (try { open $CCUSAGE_CACHE | default {} } catch { {} })
  if ($cached | describe | str starts-with "record") and (
    $CCUSAGE_FIELDS | all {|field| $field in $cached }
  ) {
    $cached
  } else {
    {}
  }
}

def active-block []: nothing -> record {
  let result = (^$NPX -y ccusage@latest blocks --json | complete)
  if $result.exit_code != 0 { return $NO_BLOCK }

  let blocks = (try { $result.stdout | from json | get -o blocks | default [] } catch { [] })
  let active = ($blocks | where ($it.isActive? | default false) | get -o 0)
  if $active == null { return $NO_BLOCK }

  # ccusage stamps `startTime` in UTC.
  let today = (date now | date to-timezone UTC | format date "%Y-%m-%d")
  {
    has_data: true
    block_cost: ($active.costUSD? | default 0 | into float)
    remaining_minutes: ($active.projection?.remainingMinutes? | default 0 | math floor)
    burn_rate: ($active.burnRate?.costPerHour? | default 0 | into float)
    daily_cost: (
      $blocks
      | where ($it.startTime? | default "" | str starts-with $today)
      | each { get costUSD? | default 0 | into float }
      | append 0.0
      | math sum
    )
  }
}

def read-ccusage []: nothing -> record {
  let cached = (read-cache)
  if ($cached | is-not-empty) { return $cached }

  let data = (active-block)
  try { $data | save --force $CCUSAGE_CACHE }
  $data
}

def format-remaining [minutes: int]: nothing -> string {
  if $minutes <= 0 { return "" }
  let hours = ($minutes // 60)
  if $hours > 0 { $"($hours)h($minutes mod 60)m left" } else { $"($minutes)m left" }
}

def format-ccusage-info [data: record]: nothing -> record<block: string, daily: string> {
  if not ($data.has_data? | default false) { return { block: "", daily: "" } }

  let details = (
    [
      (format-remaining $data.remaining_minutes)
      (if $data.burn_rate > 0 { $"(usd $data.burn_rate)/h" })
    ]
    | compact --empty
    | str join ", "
  )
  let suffix = if ($details | is-empty) { "" } else { " " + (paint $"\(($details)\)" "yellow") }

  {
    block: $"(labeled 'Block' (usd $data.block_cost) 'cyan')($suffix)"
    daily: (labeled "Today" (usd $data.daily_cost) "cyan")
  }
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

def main [] {
  let input = (open --raw /dev/stdin | from json)
  let cwd = $input.workspace.current_dir

  let tty_num = (^$GET_TTY_NUM | str trim)
  let dir_name = if $cwd == $nu.home-dir { "~" } else { $cwd | path basename }
  let row1 = $"(dim $'#($tty_num)') (paint $dir_name 'blue_bold')(format-git-info $cwd)"

  let model = ($input.model?.display_name? | default "")
  let claude = (format-claude-info $input)
  let ccusage = (format-ccusage-info (read-ccusage))

  let row2 = (
    [
      (if ($model | is-not-empty) { paint (simplify-model-name $model) "cyan" })
      $claude.ctx
      $claude.sess
      $ccusage.block
      $ccusage.daily
      (dim (date now | format date "%H:%M"))
    ]
    | compact --empty
    | str join $" (dim '|') "
  )

  print --no-newline $"($row1)\n($row2)"
}
