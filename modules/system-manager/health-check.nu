#!/usr/bin/env nu

# ==============================================================================
# System Manager Health Check
# ==============================================================================
# Verify that the named systemd units are running, or that a oneshot unit
# completed successfully. Missing units are reported and skipped.
# ==============================================================================

const PROPERTIES = [
  ActiveState
  ExecMainStartTimestampMonotonic
  ExecMainStatus
  LoadState
  Result
  Type
]

# A unit name systemd cannot parse makes systemctl print nothing, and the
# callers below all read fields off the result.
def unit-state [service: string]: nothing -> record {
  ^systemctl show ...($PROPERTIES | each {|p| $"--property=($p)" }) $service
  | lines
  | parse "{key}={value}"
  | reduce --fold {} {|row, acc| $acc | insert $row.key $row.value }
}

def is-installed [unit: record]: nothing -> bool {
  let state = ($unit.LoadState? | default "")
  ($state | is-not-empty) and ($state != "not-found")
}

# A oneshot that already ran and exited 0 is healthy even though it is inactive.
# The monotonic start timestamp is 0 until the unit has actually run.
def ran-successfully [unit: record]: nothing -> bool {
  (
    ($unit.Type? == "oneshot") and
    ($unit.Result? == "success") and
    ($unit.ExecMainStatus? == "0") and
    (($unit.ExecMainStartTimestampMonotonic? | default "0") != "0")
  )
}

def main [...services: string] {
  if ($services | is-empty) {
    print -e "usage: system-manager-health-check <service>..."
    exit 2
  }

  mut failed = false
  for service in $services {
    let unit = (unit-state $service)

    if not (is-installed $unit) {
      print -e $"service '($service)' is not installed; skipping"
      continue
    }

    if ($unit.ActiveState? == "active") or (ran-successfully $unit) {
      continue
    }

    print -e $"service '($service)' is not active"
    # `systemctl status` exits non-zero for an inactive unit, which would
    # otherwise abort the loop before the remaining services are checked.
    ^systemctl status --no-pager $service | complete | get stdout | str trim | print -e
    $failed = true
  }

  if $failed {
    exit 1
  }
}
