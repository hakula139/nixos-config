#!/usr/bin/env nu

# ==================================================================================================
# Curl Stub
# ==================================================================================================
# Stands in for curl in the model-call tests. Each call appends its arguments and the request body
# it read to `STUB_LOG` as one JSON line, then prints `STUB_REPLY`.
# ==================================================================================================

def --wrapped main [...args: string] {
  let body = (^cat | from json)
  {args: $args, body: $body} | to json --raw | $"($in)\n" | save --append $env.STUB_LOG
  print --no-newline $env.STUB_REPLY
}
