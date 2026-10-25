#!/usr/bin/env nu

# ==================================================================================================
# Changing Proxy Secret Reader
# ==================================================================================================

def main [file: string] {
  let value = (open --raw $file)
  "http://changed.proxy.example.test:8081" | save --force $file
  print --no-newline $value
}
