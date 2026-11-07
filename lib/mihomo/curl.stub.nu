#!/usr/bin/env nu

# ==================================================================================================
# curl Stub
# ==================================================================================================
# Stands in for the subscription fetch in the update tests.
# ==================================================================================================

def --wrapped main [...args: string] {
  print --no-newline $env.STUB_CURL_BODY
  exit ($env.STUB_CURL_STATUS | into int)
}
