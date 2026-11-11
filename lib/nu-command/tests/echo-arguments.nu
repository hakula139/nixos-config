#!/usr/bin/env nu

# ==================================================================================================
# Nushell Command Fixture
# ==================================================================================================
# Prints what the wrapper passes to `main`, so the check can assert the adapter's `config` and
# `flags` translation.
# ==================================================================================================

def main [
  --config: path
  --mode: string
  --count: int
] {
  print ({
    config: (if $config == null { null } else { open $config })
    mode: $mode
    count: $count
  } | to json --raw)
}
