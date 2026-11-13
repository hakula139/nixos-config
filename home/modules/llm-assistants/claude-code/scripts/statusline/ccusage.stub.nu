#!/usr/bin/env nu

# ==================================================================================================
# ccusage Stub
# ==================================================================================================
# Records invocations and emits payloads or failures selected by CCUSAGE_MODE.
# ==================================================================================================

def --wrapped main [...args: string] {
  let lock = ($env.STUB_LOCK? | default "")
  let mode = ($env.CCUSAGE_MODE? | default "success")
  {
    args: $args
    lock_exists: (if ($lock | is-empty) { false } else { $lock | path exists })
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  let payload = match $args {
    ["claude" "blocks" "--active" "--json" "--offline"] => {
      match $mode {
        "fail-blocks" => {
          print --stderr "Injected blocks query failure"
          exit 1
        }
        "scalar-blocks" => 0
        _ => {
          blocks: [{
            isActive: true
            costUSD: 12.5
            projection: {remainingMinutes: 185}
            burnRate: {costPerHour: 3.25}
          }]
        }
      }
    }
    ["claude" "daily" "--since" $since "--until" $until "--json" "--offline"] => {
      if $mode == "fail-daily" {
        print --stderr "Injected daily query failure"
        exit 1
      }
      {totals: {totalCost: 40.75}}
    }
    _ => {
      print --stderr $"Unexpected ccusage arguments: ($args | to nuon)"
      exit 2
    }
  }
  print ($payload | to json)
}
