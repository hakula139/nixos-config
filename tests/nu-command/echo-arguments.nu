#!/usr/bin/env nu

# ==================================================================================================
# Nushell Command Fixture
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
