#!/usr/bin/env nu

# ==================================================================================================
# Claude Code Session Arguments Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join session-args.sh)

const SESSION = ["--settings=/settings.json" "--mcp-config=/mcp.json"]

# The argv Claude Code receives after the launcher sources the script over `argv`.
def session-args [argv: list<string>]: nothing -> list<string> {
  let script = (mktemp)

  open --raw $SCRIPT
  | str replace "@mcpFlag@" "--mcp-config=/mcp.json"
  | save --force $script

  let launcher = 'source "$0"; printf "%s\0" "$@"'
  with-env {__claude_settings: /settings.json} {
    ^bash -c $launcher $script ...$argv | split row (char nul) | drop
  }
}

def "test session flags reach sessions but not subcommands" [] {
  let cases = [
    [argv session];
    [[] true]
    [["fix the failing test"] true]
    [[Hello] true]
    [[-- hello] true]
    [[-p "summarize" --model opus] true]
    [[--resume] true]
    [[agents --model opus] true]
    [[mcp list] false]
    [[plugin install foo] false]
    [[setup-token] false]
  ]

  for case in $cases {
    let expected = if $case.session { $SESSION ++ $case.argv } else { $case.argv }
    assert equal (session-args $case.argv) $expected $"argv: ($case.argv | to nuon)"
  }
}
