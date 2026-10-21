#!/usr/bin/env nu

# ==================================================================================================
# Model Call Stub
# ==================================================================================================
# Stands in for the model caller in the comment-gate tests. It prints `STUB_REPLY`, or prints
# `STUB_ERROR` to stderr and exits 1 when that is set.
# ==================================================================================================

def main [] {
  ^cat | ignore
  let error = ($env | get -o STUB_ERROR | default "")
  if ($error | is-not-empty) {
    print --stderr $error
    exit 1
  }
  print --no-newline $env.STUB_REPLY
}
