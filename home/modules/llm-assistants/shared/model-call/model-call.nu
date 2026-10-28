#!/usr/bin/env nu

# ==================================================================================================
# Shared Model Call
# ==================================================================================================
# Sends one chat completion to the corp gateway and prints the reply. Without a usable reply it
# exits nonzero with the reason on stderr.
# ==================================================================================================

def fail [reason: string] {
  print --stderr $"model-call: ($reason)"
  exit 1
}

def main [config_file: string] {
  let config = (open $config_file)
  let gateway = $config.gateway
  let request = (^cat | from json)

  let body = {
    model: $request.model
    max_tokens: $request.maxTokens
    stream: false
    tool_choice: "none"
    messages: [
      {role: "system", content: $request.system}
      {role: "user", content: $request.user}
    ]
  }
  let shaped = if ($request | get -o json | default false) {
    $body | insert response_format {type: "json_object"}
  } else {
    $body
  }
  let curl = $config.curl
  # The gateway's advertised IPv6 endpoint closes during TLS. The token stays off curl's command
  # line, which other local users can read.
  let run = (
    $shaped
    | to json
    | ^$curl ...$config.curlArgs
      --ipv4
      --cacert $gateway.caFile
      --variable $"token@($gateway.tokenFile)"
      --expand-header "Authorization: Bearer {{token:trim}}"
      --header "content-type: application/json"
      --data @-
      $"($gateway.baseUrl)/v1/chat/completions"
    | complete
  )
  if $run.exit_code != 0 {
    fail ($run.stderr | str trim)
  }

  let response = (try { $run.stdout | from json } catch { null })
  if not ($response | describe | str starts-with "record") {
    fail "the gateway reply is not a JSON object"
  }
  let finish = ($response | get -o choices.0.finish_reason | default "none")
  if $finish != "stop" {
    fail $"the gateway reply ended with finish_reason ($finish)"
  }
  let reply = ($response | get -o choices.0.message.content)
  if ($reply | describe) != "string" or ($reply | str trim | is-empty) {
    fail "the gateway reply carries no text"
  }
  print --no-newline $reply
}
