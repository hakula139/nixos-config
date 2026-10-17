#!/usr/bin/env nu

# ==================================================================================================
# CSpell Stub
# ==================================================================================================
# Stands in for cspell in the auto-format tests. Each call appends the stub's own path, its working
# directory, and its arguments to `STUB_LOG`, one JSON line per call.
# ==================================================================================================

def --wrapped main [...args: string] {
  {bin: $env.CURRENT_FILE, cwd: $env.PWD, args: $args}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG
}
