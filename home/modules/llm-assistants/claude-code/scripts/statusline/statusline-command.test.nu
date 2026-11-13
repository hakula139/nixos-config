#!/usr/bin/env nu

# ==================================================================================================
# Claude Code Status Line Command Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "statusline-command.nu")
source $SCRIPT

const CACHE_NAME = "statusline-usage.json"
const LOCK_NAME = "statusline-usage.lock"

def utc-today []: nothing -> string {
  date now | date to-timezone "UTC" | format date "%Y%m%d"
}

def cached-usage [today: string]: nothing -> record {
  {
    date: $today
    has_block: true
    has_daily: true
    block_cost: 4.5
    remaining_minutes: 125
    burn_rate: 1.75
    daily_cost: 8.25
  }
}

def refreshed-usage [today: string]: nothing -> record {
  {
    date: $today
    has_block: true
    has_daily: true
    block_cost: 12.5
    remaining_minutes: 185
    burn_rate: 3.25
    daily_cost: 40.75
  }
}

def expected-flock-call [cache: path]: nothing -> record {
  {
    lock: (($cache | path dirname) | path join $LOCK_NAME)
    command: [
      $nu.current-exe
      $SCRIPT
      "--cache" $cache
      "--refresh-usage"
    ]
  }
}

def blocks-call []: nothing -> record {
  {
    args: [
      "claude"
      "blocks"
      "--active"
      "--json"
      "--offline"
    ]
    lock_exists: true
  }
}

def refresh-calls [today: string]: nothing -> list<record> {
  [
    (blocks-call)
    {
      args: [
        "claude"
        "daily"
        "--since" $today
        "--until" $today
        "--json"
        "--offline"
      ]
      lock_exists: true
    }
  ]
}

def read-calls [log: path]: nothing -> list<record> {
  if ($log | path exists) {
    open $log | from json --objects
  } else {
    []
  }
}

def usage-fields [output: string]: nothing -> record {
  let columns = (
    $output
    | ansi strip
    | lines
    | get -o 1
    | default ""
    | split row " | "
  )
  {
    block: ($columns | where ($it | str starts-with "Block:") | first | default "")
    daily: ($columns | where ($it | str starts-with "Today:") | first | default "")
  }
}

def invoke-statusline [
  dir: path
  --cache-name: string = $CACHE_NAME
  --ccusage-mode: string = "success" # Stub mode: success, fail-blocks, scalar-blocks, or fail-daily
  --fail-mv
  --lock-held
]: nothing -> record {
  let cache = ($dir | path join $cache_name)
  let lock = ($dir | path join $LOCK_NAME)
  let ccusage_log = ($dir | path join "ccusage-calls.jsonl")
  let flock_log = ($dir | path join "flock-calls.jsonl")
  let config = ($dir | path join "models.json")
  let cwd = ($dir | path join "work")
  mkdir $cwd
  {models: {}} | save $config

  let run = with-env {
    CCUSAGE_MODE: $ccusage_mode
    FLOCK_LOG: $flock_log
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_FLOCK_HELD: (if $lock_held { "1" } else { "0" })
    STUB_LOCK: $lock
    STUB_LOG: $ccusage_log
    STUB_MV_FAIL: (if $fail_mv { "1" } else { "0" })
    TZ: "UTC"
  } {
    (
      {workspace: {current_dir: $cwd}}
      | to json
      | ^$nu.current-exe --no-config-file
        $SCRIPT
        --config $config
        --cache $cache
      | complete
    )
  }

  {
    cache: $cache
    lock: $lock
    run: $run
    calls: (read-calls $ccusage_log)
    flock_calls: (read-calls $flock_log)
    usage: (usage-fields $run.stdout)
    temporary_files: (ls $dir | where ($it.name | str ends-with ".tmp") | get name)
  }
}

def assert-refreshed [result: record, today: string] {
  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.flock_calls [(expected-flock-call $result.cache)]
  assert equal $result.calls (refresh-calls $today)
  assert equal $result.usage {
    block: "Block: $12.50 (3h5m left, $3.25/h)"
    daily: "Today: $40.75"
  }
  assert equal (open $result.cache) (refreshed-usage $today)
  assert ($result.lock | path exists)
}

def assert-stale-preserved [result: record, original: string] {
  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.flock_calls [(expected-flock-call $result.cache)]
  assert equal $result.usage {
    block: "Block: $4.50 (2h5m left, $1.75/h)"
    daily: "Today: $8.25"
  }
  assert equal (open --raw $result.cache) $original
  assert equal $result.temporary_files []
  assert ($result.lock | path exists)
}

def "test fresh cache skips flock and ccusage and renders cached usage" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  (cached-usage $today) | save ($dir | path join $CACHE_NAME)

  let result = (invoke-statusline $dir)
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal $result.flock_calls []
  assert equal $result.calls []
  assert equal $result.usage {
    block: "Block: $4.50 (2h5m left, $1.75/h)"
    daily: "Today: $8.25"
  }
}

def "test unlocked stale cache refreshes once and keeps its lock file" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  let cache = ($dir | path join $CACHE_NAME)
  (cached-usage $today) | save $cache
  touch -d "5 minutes ago" $cache

  let result = (invoke-statusline $dir)

  assert-refreshed $result $today
}

def "test blocks query failure preserves stale cache without publishing partial usage" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  let cache = ($dir | path join $CACHE_NAME)
  (cached-usage $today) | save $cache
  let original = (open --raw $cache)
  touch -d "5 minutes ago" $cache

  let result = (invoke-statusline $dir --ccusage-mode fail-blocks)

  assert-stale-preserved $result $original
  assert equal $result.calls [(blocks-call)]
}

def "test scalar blocks response preserves stale cache without querying daily" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  let cache = ($dir | path join $CACHE_NAME)
  (cached-usage $today) | save $cache
  let original = (open --raw $cache)
  touch -d "5 minutes ago" $cache

  let result = (invoke-statusline $dir --ccusage-mode scalar-blocks)

  assert-stale-preserved $result $original
  assert equal $result.calls [(blocks-call)]

  let shape_log = ($dir | path join "ccusage-shape.jsonl")
  let shape_error = with-env {
    CCUSAGE_MODE: "scalar-blocks"
    PATH: $env.NU_TEST_STUBS
    STUB_LOCK: $result.lock
    STUB_LOG: $shape_log
  } {
    try {
      ccusage-json [blocks --active]
      ""
    } catch {|error| $error.msg }
  }
  assert equal $shape_error "ccusage blocks --active returned invalid JSON"
  assert equal (read-calls $shape_log) [(blocks-call)]
}

def "test daily query failure preserves stale cache after a successful blocks query" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  let cache = ($dir | path join $CACHE_NAME)
  (cached-usage $today) | save $cache
  let original = (open --raw $cache)
  touch -d "5 minutes ago" $cache

  let result = (invoke-statusline $dir --ccusage-mode fail-daily)

  assert-stale-preserved $result $original
  assert equal $result.calls (refresh-calls $today)
}

def "test save failure preserves stale cache and cleans temporary state" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  let cache_name = ((0..239 | each { "u" } | str join) + ".json")
  let cache = ($dir | path join $cache_name)
  (cached-usage $today) | save $cache
  let original = (open --raw $cache)
  touch -d "5 minutes ago" $cache

  let result = (invoke-statusline $dir --cache-name $cache_name)

  assert-stale-preserved $result $original
  assert equal $result.calls (refresh-calls $today)
}

def "test publication failure preserves stale cache and cleans temporary state" [] {
  let dir = (mktemp --directory)
  let today = (utc-today)
  let cache = ($dir | path join $CACHE_NAME)
  (cached-usage $today) | save $cache
  let original = (open --raw $cache)
  touch -d "5 minutes ago" $cache

  let result = (invoke-statusline $dir --fail-mv)

  assert-stale-preserved $result $original
  assert equal $result.calls (refresh-calls $today)
}

def "test held lock respects stale fallback age bound" [] {
  let today = (utc-today)
  let cases = [
    {name: "five-minute stale", age: "5 minutes ago", expected_stale: true}
    {name: "eleven-minute expired", age: "11 minutes ago", expected_stale: false}
  ]
  for case in $cases {
    let dir = (mktemp --directory)
    let cache = ($dir | path join $CACHE_NAME)
    (cached-usage $today) | save $cache
    touch -d $case.age $cache

    let result = (invoke-statusline $dir --lock-held)

    let expected_usage = if $case.expected_stale {
      {
        block: "Block: $4.50 (2h5m left, $1.75/h)"
        daily: "Today: $8.25"
      }
    } else {
      {block: "", daily: ""}
    }
    assert equal $result.run.exit_code 0 $"($case.name): ($result.run.stderr)"
    let expected_flock = [(expected-flock-call $result.cache)]
    assert equal $result.flock_calls $expected_flock $"($case.name): lock attempt"
    assert equal $result.calls [] $"($case.name): ccusage calls"
    assert equal $result.usage $expected_usage $"($case.name): usage fields"
    assert ($result.lock | path exists) $"($case.name): persistent lock file"
  }
}

def "test held lock without cache renders no usage" [] {
  let dir = (mktemp --directory)

  let result = (invoke-statusline $dir --lock-held)
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal $result.flock_calls [(expected-flock-call $result.cache)]
  assert equal $result.calls []
  assert equal $result.usage {block: "", daily: ""}
  assert ($result.lock | path exists)
}
