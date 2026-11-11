#!/usr/bin/env bash

# ==================================================================================================
# Nushell Command Integration Test
# ==================================================================================================
# Runs the wrapped fixture and asserts the adapter's `config`, `flags`, and `makeWrapperArgs`
# translation, which devkit's own wrapper tests do not cover.
# ==================================================================================================

set -euo pipefail

configured=$1
plain=$2

assert() {
  local output=$1
  local query=$2
  if ! jq -e "$query" <<<"$output" >/dev/null; then
    echo "failed: $query" >&2
    echo "$output" >&2
    exit 1
  fi
}

output=$(NU_COMMAND_TEST_ENV=caller "$configured" alpha beta)

assert "$output" '.config.name == "adapter"'
assert "$output" '.config.nested.value == 2'
assert "$output" '.mode == "fast"'
assert "$output" '.env == "wrapper"'
assert "$output" '.rest == ["alpha", "beta"]'
assert "$output" '.count == 5'

output=$(NU_COMMAND_TEST_ENV=caller "$plain" alpha)

assert "$output" '.config == null'
assert "$output" '.mode == null'
assert "$output" '.count == null'
assert "$output" '.rest == ["alpha"]'
assert "$output" '.env == "caller"'
