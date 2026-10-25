#!/usr/bin/env nu

# ==================================================================================================
# Changing Proxy Secret Reader
# ==================================================================================================

def --wrapped main [...args: string] {
  let file = ($args | last)
  let value = (open --raw $file)
  "http://changed.proxy.example.test:8081" | save --force $file
  print --no-newline $value
}
