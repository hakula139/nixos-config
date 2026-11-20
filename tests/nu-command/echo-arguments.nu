#!/usr/bin/env nu

# ==================================================================================================
# Nushell Command Fixture
# ==================================================================================================

def main [
  --config: path
  --mode: string
  --count: int
] {
  {
    config: (if $config == null { null } else { open $config })
    mode: $mode
    count: $count
  }
  | to json --raw
  | print $in
}
