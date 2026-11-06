#!/usr/bin/env nu

# ==================================================================================================
# Lsof Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  let exit_code = ($env.STUB_LSOF_EXIT? | default "0" | into int)
  if $exit_code != 0 {
    print -e "lsof: WARNING: can't stat() fuse file system /mnt/example"
    exit $exit_code
  }
  print --no-newline ($env.STUB_LSOF_OUTPUT? | default "")
}
