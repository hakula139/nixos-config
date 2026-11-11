#!/usr/bin/env nu

# ==================================================================================================
# Nushell Command Fixture
# ==================================================================================================
# Prints what the wrapper passes to `main`, so the integration test can check the adapter's
# translation of its `config`, `flags`, and `makeWrapperArgs` arguments.
# ==================================================================================================

def main [
  ...rest: string
  --config: path
  --mode: string
  --count: int
] {
  print ({
    config: (if $config == null { null } else { open $config })
    mode: $mode
    count: $count
    rest: $rest
    env: ($env | get -o NU_COMMAND_TEST_ENV)
  } | to json --raw)
}
