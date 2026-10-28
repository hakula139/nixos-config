#!/usr/bin/env nu

# ==================================================================================================
# Model Call Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join model-call.nu)

const TOKEN = "stub-gateway-token"
const CURL_ARGS = [
  --fail
  --silent
  --show-error
  --connect-timeout "5"
  --max-time "90"
]

# `run` is the completed model call, `calls` holds what each curl call received, and `token_file`
# is the token's path.
def call [request: record, reply: record]: nothing -> record {
  let dir = (mktemp --directory)
  let config_file = ($dir | path join config.json)
  let token_file = ($dir | path join token)
  let log = ($dir | path join calls.jsonl)

  $"($TOKEN)\n" | save $token_file
  {
    gateway: {baseUrl: "https://gateway.test", tokenFile: $token_file, caFile: "/ca.pem"}
    curl: ($env.NU_TEST_STUBS | path join curl)
    curlArgs: $CURL_ARGS
  }
  | to json
  | save $config_file

  let run = with-env {STUB_LOG: $log, STUB_REPLY: ($reply | to json)} {
    $request | to json | ^$nu.current-exe --no-config-file $SCRIPT $config_file | complete
  }
  {run: $run, calls: (open $log | from json --objects), token_file: $token_file}
}

def reply [content: string, finish: string]: nothing -> record {
  {choices: [{finish_reason: $finish, message: {content: $content}}]}
}

def "test a request passes the token by file and prints the reply" [] {
  let request = {model: stub, maxTokens: 64, system: "Judge.", user: "Text.", json: true}

  let result = (call $request (reply "ok: true" stop))
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal $result.run.stdout "ok: true"
  assert equal $result.calls [
    {
      args: [
        ...$CURL_ARGS
        --ipv4
        --cacert /ca.pem
        --variable $"token@($result.token_file)"
        --expand-header "Authorization: Bearer {{token:trim}}"
        --header "content-type: application/json"
        --data @-
        https://gateway.test/v1/chat/completions
      ]
      body: {
        model: stub
        max_tokens: 64
        stream: false
        tool_choice: none
        messages: [{role: system, content: "Judge."}, {role: user, content: "Text."}]
        response_format: {type: json_object}
      }
    }
  ]
}

def "test a reply cut short fails with its finish reason" [] {
  let request = {model: stub, maxTokens: 64, system: "Judge.", user: "Text."}

  let result = (call $request (reply "ok:" length))

  assert equal $result.run.exit_code 1
  assert equal $result.run.stdout ""
  assert equal $result.run.stderr "model-call: the gateway reply ended with finish_reason length\n"
}
