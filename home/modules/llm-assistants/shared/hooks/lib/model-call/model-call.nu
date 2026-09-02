#!/usr/bin/env nu

# ==============================================================================
# Shared Model Call
# ==============================================================================
# Two legs: the profile's gateway, then Codex. Codex carries its own
# credentials, so it is the only leg that survives a subscription profile,
# where the gateway variables are absent.
# ==============================================================================

def gateway [request: record, config: record]: nothing -> string {
  # Claude profile API suffix
  let base = ($env | get -o ANTHROPIC_BASE_URL | default "" | str replace -r '/anthropic$' '')
  let token = ($env | get -o ANTHROPIC_AUTH_TOKEN | default "")
  if ($base | is-empty) or ($token | is-empty) {
    return ""
  }

  let body = {
    model: ($request | get -o model | default $config.gatewayModel)
    max_tokens: $request.maxTokens
    stream: false
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
  let ca = ($env | get -o NODE_EXTRA_CA_CERTS | default "")
  let cacert = if ($ca | is-empty) { [] } else { [--cacert $ca] }
  let curl = $config.curl
  # The gateway's advertised IPv6 endpoint closes during TLS.
  let run = (
    $shaped
    | to json
    | ^$curl --ipv4 --silent --show-error --fail --max-time $config.gatewayTimeout
      ...$cacert
      --header $"Authorization: Bearer ($token)"
      --header "content-type: application/json"
      --data @-
      $"($base)/v1/chat/completions"
    | complete
  )
  if $run.exit_code != 0 {
    return ""
  }

  let response = ($run.stdout | from json)
  if ($response | describe | str starts-with "record") == false {
    return ""
  }
  if ($response | get -o choices.0.finish_reason | default "") != "stop" {
    return ""
  }
  let reply = ($response | get -o choices.0.message.content | default "")
  if ($reply | describe) == "string" { $reply } else { "" }
}

def codex [request: record, config: record]: nothing -> string {
  let codex_bin = $config.codex
  if (which $codex_bin | is-empty) {
    return ""
  }
  let timeout = $config.timeout
  # Codex has no response-format switch, so JSON mode is asked for in words.
  let instruction = if ($request | get -o json | default false) {
    "Reply with one JSON object and nothing else. No prose, no code fence."
  } else {
    ""
  }
  # `--ignore-user-config` skips the MCP servers a normal Codex session loads,
  # which is what keeps this leg near the gateway's latency. `codex exec` takes
  # no deadline of its own, so the bound comes from outside.
  let run = (
    [$request.system $instruction "" $request.user]
    | where ($it | is-not-empty)
    | str join "\n"
    | ^$timeout $config.codexTimeout $codex_bin exec
      --ephemeral
      --ignore-user-config
      --skip-git-repo-check
      --color never
      --sandbox read-only
      --model $config.codexModel
      -
    | complete
  )
  if $run.exit_code != 0 { "" } else { $run.stdout }
}

def reply [request: record, config: record]: nothing -> string {
  let first = (try { gateway $request $config } catch { "" })
  if ($first | str trim | is-not-empty) {
    return $first
  }
  try { codex $request $config } catch { "" }
}

def main [config_file: string] {
  let config = (open $config_file)
  let request = (^cat | from json)
  if ($request | describe | str starts-with "record") == false {
    return
  }
  let out = (reply $request $config)
  if ($out | str trim | is-not-empty) {
    print --no-newline $out
  }
}
