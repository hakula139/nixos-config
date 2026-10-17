#!/usr/bin/env nu

# ==================================================================================================
# lsof Stub
# ==================================================================================================
# Stands in for lsof in the cleanup tests. Prints each path in the newline-separated `STUB_OPEN` as
# an open file in `-F n` form, then exits with `STUB_STATUS`.
# ==================================================================================================

def --wrapped main [...args: string] {
  $env.STUB_OPEN? | default "" | lines | each { $"p1\nn($in)" } | str join "\n" | print
  exit ($env.STUB_STATUS? | default "0" | into int)
}
