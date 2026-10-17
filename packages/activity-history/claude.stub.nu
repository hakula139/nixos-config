#!/usr/bin/env nu

# ==================================================================================================
# Claude Code Stub
# ==================================================================================================
# Stands in for headless Claude Code in the activity-history tests, answering every request with a
# log that has both required sections.
# ==================================================================================================

def --wrapped main [...args: string] {
  ^cat | ignore
  {stop_reason: end_turn, result: "## Timeline\n\n## Draft\n\n- Unattributed: 0m"} | to json
}
