#!/usr/bin/env nu

# ==================================================================================================
# Teammate Idle
# ==================================================================================================
# A teammate's plain final response never reaches its lead, so this nudges it once per session to
# send the report with SendMessage.
# ==================================================================================================

# Nudge an idle teammate once per session to send its report with SendMessage.
def main [] {
  let input = (^cat | from json)
  let session_id = ($input | get -o session_id | default --empty "unknown")
  let teammate_name = ($input | get -o teammate_name)

  let flag = $"/tmp/claude-team-nudged-($session_id)"
  if not ($flag | path exists) {
    touch $flag
    print --stderr $"Teammate ($teammate_name): if you left your final report as plain text, send it to team-lead with SendMessage, since the lead never sees plain text."
    exit 2
  }
}
