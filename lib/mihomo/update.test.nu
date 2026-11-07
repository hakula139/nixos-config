#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Update Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "update.nu")
const SUBSCRIPTION = ($SCRIPT_DIR | path join "fixtures/update/subscription/config.yaml")

const PREVIOUS = "log-level: info\n"
const SECRET = "test-secret"
const SUBSCRIPTION_URL = "https://sub.example.com/x"
const BASE_TUN = {enable: false, stack: "gvisor"}

def run-update [
  curl_status: int
  body: string
  mihomo_status: int
  previous: bool
]: nothing -> record {
  let dir = (mktemp --directory)
  let config_dir = ($dir | path join "mihomo")
  let secret_file = ($dir | path join "secret")
  let url_file = ($dir | path join "subscription-url")
  let config_file = ($dir | path join "update.json")
  let target = ($config_dir | path join "config.yaml")

  mkdir $config_dir
  if $previous {
    $PREVIOUS | save $target
  }
  $SECRET | save $secret_file
  $SUBSCRIPTION_URL | save $url_file

  {
    baseConfig: {
      "mixed-port": 7897
      "log-level": "warning"
      "allow-lan": false
      "tun": $BASE_TUN
    }
    configDir: $config_dir
    secretFile: $secret_file
    subscriptionUrlFile: $url_file
    proxyVars: []
    curlArgs: []
    ruleProviders: {}
    prependRules: ["DOMAIN-SUFFIX,internal.example,DIRECT"]
  }
  | to json
  | save $config_file

  let run = with-env {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_CURL_STATUS: ($curl_status | into string)
    STUB_CURL_BODY: $body
    STUB_MIHOMO_STATUS: ($mihomo_status | into string)
  } {
    (
      ^$nu.current-exe --no-config-file
        $SCRIPT --config $config_file
      | complete
    )
  }

  let staging = (
    ls --all $config_dir
    | get name
    | path basename
    | filter {|name| $name | str starts-with ".config.staging." }
  )

  {run: $run, target: $target, staging: $staging}
}

def "test the update stages, validates, and replaces the config" [] {
  let subscription = (open --raw $SUBSCRIPTION)
  let cases = [
    [name curl_status body mihomo_status previous status];
    ["fetch fails" 18 $subscription 0 true 1]
    ["mihomo rejects" 0 $subscription 1 true 1]
    ["success" 0 $subscription 0 true 0]
    ["success without an existing config" 0 $subscription 0 false 0]
  ]

  for case in $cases {
    let result = (run-update $case.curl_status $case.body $case.mihomo_status $case.previous)
    let context = $"($case.name): ($result.run.stderr)"

    assert equal $result.run.exit_code $case.status $context
    assert equal $result.staging [] $"($context): staging file left behind"

    if $case.status != 0 {
      assert equal (open --raw $result.target) $PREVIOUS $"($context): config changed on failure"
      continue
    }

    let merged = (open $result.target)
    assert equal $merged.mixed-port 7897 $context
    assert equal $merged.allow-lan false $context
    assert equal $merged.tun $BASE_TUN $context
    assert equal $merged.secret $SECRET $context
    assert equal $merged.rules [
      "DOMAIN-SUFFIX,internal.example,DIRECT"
      "DOMAIN,sub.example.com,DIRECT"
      "MATCH,DIRECT"
    ] $context

    if $case.previous {
      assert equal (open --raw $"($result.target).bak") $PREVIOUS $context
    } else {
      assert not ($"($result.target).bak" | path exists) $context
    }
  }
}
