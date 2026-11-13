#!/usr/bin/env nu

# ==================================================================================================
# mv Stub
# ==================================================================================================
# Renames with Nushell's builtin, or fails when STUB_MV_FAIL is 1.
# ==================================================================================================

def main [--force, source: path, destination: path] {
  if ($env.STUB_MV_FAIL? | default "0") == "1" {
    print --stderr "Injected cache publication failure"
    exit 1
  }

  mv --force $source $destination
}
