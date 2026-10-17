#!/usr/bin/env nu

# ==================================================================================================
# CSpell Stub
# ==================================================================================================
# Stands in for cspell in the auto-format tests. Each call appends its working directory and
# arguments to `STUB_LOG`, one JSON line per call.
# ==================================================================================================

def --wrapped main [...args: string] {
  {cwd: $env.PWD, args: $args} | to json --raw | $"($in)\n" | save --append $env.STUB_LOG
}
