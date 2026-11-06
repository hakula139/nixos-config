#!/usr/bin/env nu

# ==================================================================================================
# curl Stub
# ==================================================================================================
# Stands in for the subscription fetch in the update tests.
# ==================================================================================================

def --wrapped main [...args: string] {
  let status = ($env.STUB_CURL_STATUS? | default "0" | into int)
  if $status != 0 {
    exit $status
  }

  print --no-newline ($env.STUB_CURL_BODY? | default "")
}
