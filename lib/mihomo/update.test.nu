#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Update Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "update.nu")

const PREVIOUS = "log-level: info\n"
const SECRET = "test-secret"
const SUBSCRIPTION_URL = "https://sub.example.com/x"

const SUBSCRIPTION = "
proxies: []
proxy-groups: []
rules:
  - MATCH,DIRECT
"

def run-update [
  curl_status: int
  body: string
  mihomo_status: int
  lan_host: bool
]: nothing -> record {
  let dir = (mktemp --directory)
  let config_dir = ($dir | path join "mihomo")
  let secret_file = ($dir | path join "secret")
  let url_file = ($dir | path join "subscription-url")
  let config_file = ($dir | path join "update.json")
  let target = ($config_dir | path join "config.yaml")

  mkdir $config_dir
  $PREVIOUS | save $target
  $SECRET | save $secret_file
  $SUBSCRIPTION_URL | save $url_file

  {
    baseConfig: {
      "mixed-port": 7897
      "log-level": "warning"
      "lan-allowed-ips": ["127.0.0.0/8"]
    }
    configDir: $config_dir
    secretFile: $secret_file
    subscriptionUrlFile: $url_file
    proxyVars: []
    curlArgs: []
    ruleProviders: {}
    prependRules: ["RULE-SET,Intranet,DIRECT"]
    lanAllowHostAddress: $lan_host
  }
  | to json
  | save $config_file

  let run = with-env {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_CURL_STATUS: ($curl_status | into string)
    STUB_CURL_BODY: $body
    STUB_MIHOMO_STATUS: ($mihomo_status | into string)
  } {
    ^$nu.current-exe --no-config-file $SCRIPT --config $config_file | complete
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
  let cases = [
    [name curl_status body mihomo_status lan_host status message];
    ["fetch fails" 22 "" 0 false 1 "subscription fetch failed"]
    ["empty body" 0 "  \n" 0 false 1 "downloaded config is empty"]
    ["mihomo rejects" 0 $SUBSCRIPTION 1 false 1 "mihomo rejected the merged config"]
    ["success" 0 $SUBSCRIPTION 0 false 0 ""]
    ["success with container access" 0 $SUBSCRIPTION 0 true 0 ""]
  ]

  for case in $cases {
    let result = (run-update $case.curl_status $case.body $case.mihomo_status $case.lan_host)
    let context = $"($case.name): ($result.run.stderr)"

    assert equal $result.run.exit_code $case.status $context
    assert equal $result.staging [] $"($context): staging file left behind"

    if $case.status != 0 {
      assert str contains $result.run.stderr $case.message $context
      assert equal (open --raw $result.target) $PREVIOUS $"($context): config changed on failure"
      continue
    }

    let merged = (open $result.target)
    assert equal $merged."mixed-port" 7897 $context
    assert equal $merged."log-level" "warning" $context
    assert equal $merged.secret $SECRET $context
    assert equal ($merged.rules | first 2) [
      "RULE-SET,Intranet,DIRECT"
      "DOMAIN,sub.example.com,DIRECT"
    ] $context
    assert equal (open --raw $"($result.target).bak") $PREVIOUS $context

    let expected_allowed = if $case.lan_host {
      ["127.0.0.0/8" "10.0.0.5/32"]
    } else {
      ["127.0.0.0/8"]
    }
    assert equal $merged."lan-allowed-ips" $expected_allowed $context
  }
}
