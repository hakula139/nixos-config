#!/usr/bin/env nu

# ==================================================================================================
# Clash Subscription Config Renderer Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "render-config.nu")

const ALPHA_REALITY = {
  name: "alpha-reality"
  server: "alpha.example.com"
  reality-opts: {
    public-key: "pub-alpha"
  }
}

const ALPHA_WS = {
  name: "alpha-ws"
  server: "alpha.example.com"
}

const BETA_REALITY = {
  name: "beta-reality"
  server: "beta.example.com"
  reality-opts: {
    public-key: "pub-beta"
  }
}

const RULE_PROVIDERS = {
  Local: {
    type: "inline"
    payload: ["DOMAIN,example.com"]
  }
}

const RULES = [
  "RULE-SET,Local,DIRECT"
  "MATCH,PROXY"
]

# Run the renderer in a temporary directory pre-populated with a stale YAML and an unrelated file.
def render [users_raw: string]: nothing -> record {
  let dir = (mktemp --directory)
  let users_file = ($dir | path join "users.json")
  let config_file = ($dir | path join "render.json")
  let output = ($dir | path join "out")

  $users_raw | save $users_file

  {
    usersFile: $users_file
    outputDir: $output
    levels: {
      user: {
        proxies: [$ALPHA_REALITY $ALPHA_WS]
        proxy-groups: [
          {
            name: "PROXY"
            proxies: ["alpha-reality" "alpha-ws"]
          }
        ]
      }
      admin: {
        proxies: [$ALPHA_REALITY $BETA_REALITY]
        proxy-groups: [
          {
            name: "PROXY"
            proxies: ["alpha-reality" "beta-reality"]
          }
        ]
      }
    }
    rule-providers: $RULE_PROVIDERS
    rules: $RULES
  }
  | to json
  | save $config_file

  mkdir $output
  "stale" | save ($output | path join "stale-uuid.yaml")
  "keep" | save ($output | path join "notes.txt")

  let run = run-script $SCRIPT --config $config_file
  {
    run: $run
    output: $output
  }
}

def render-users [users: record]: nothing -> record {
  render ($users | to json)
}

def subscriptions [output: string]: nothing -> list<string> {
  ls $output
  | get name
  | path basename
  | where {|name| $name | str ends-with ".yaml" }
  | sort
}

def "test renders per-level subscriptions with credentials and prunes stale files" [] {
  let result = (render-users {
    users: [
      {
        name: "alice"
        uuid: "alice-uuid"
        shortId: "00"
        level: "ADMIN"
      }
      {
        name: "bob"
        uuid: "0123"
        shortId: "b2"
      }
      {
        name: "eve"
        uuid: "eve-uuid"
        shortId: "e5"
        level: "root"
      }
    ]
  })
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal (open ($result.output | path join "alice-uuid.yaml")) {
    proxies: [
      ($ALPHA_REALITY | upsert uuid "alice-uuid" | upsert reality-opts.short-id "00")
      ($BETA_REALITY | upsert uuid "alice-uuid" | upsert reality-opts.short-id "00")
    ]
    proxy-groups: [
      {
        name: "PROXY"
        proxies: ["alpha-reality" "beta-reality"]
      }
    ]
    rule-providers: $RULE_PROVIDERS
    rules: $RULES
  }

  assert equal (open ($result.output | path join "0123.yaml")) {
    proxies: [
      ($ALPHA_REALITY | upsert uuid "0123" | upsert reality-opts.short-id "b2")
      ($ALPHA_WS | upsert uuid "0123")
    ]
    proxy-groups: [
      {
        name: "PROXY"
        proxies: ["alpha-reality" "alpha-ws"]
      }
    ]
    rule-providers: $RULE_PROVIDERS
    rules: $RULES
  }

  assert str contains $result.run.stderr "Skipping user eve: unknown level 'root'"
  assert equal (subscriptions $result.output) ["0123.yaml" "alice-uuid.yaml"]
  assert (($result.output | path join "notes.txt") | path exists)
  assert equal (ls -l ($result.output | path join "alice-uuid.yaml") | get 0.mode) "rw-r-----"
}

def "test invalid user entries fail without pruning existing subscriptions" [] {
  let result = (render-users {
    users: [
      {
        name: "eve"
        uuid: "eve-uuid"
        level: "admin"
      }
      {
        name: "mallory"
        uuid: "mallory-uuid"
        shortId: "m1"
        level: 42
      }
      {
        uuid: "nameless-uuid"
        shortId: "n1"
      }
      "not-a-record"
    ]
  })

  assert equal $result.run.exit_code 1
  assert str contains $result.run.stderr "Skipping user eve: missing required fields uuid or shortId"
  assert str contains $result.run.stderr "Skipping user mallory: non-string level"
  assert str contains $result.run.stderr "Skipping user entry missing required field: name"
  assert str contains $result.run.stderr "Skipping malformed user entry"
  assert equal (subscriptions $result.output) ["stale-uuid.yaml"]
}

def "test invalid users file fails without pruning existing subscriptions" [] {
  let bad_json = (render "{not valid json")
  assert equal $bad_json.run.exit_code 1
  assert str contains $bad_json.run.stderr "Invalid JSON in users file"
  assert equal (subscriptions $bad_json.output) ["stale-uuid.yaml"]

  let bad_shape = (render '{"users": "not-a-list"}')
  assert equal $bad_shape.run.exit_code 1
  assert str contains $bad_shape.run.stderr 'Users file must contain an object with a "users" array'
  assert equal (subscriptions $bad_shape.output) ["stale-uuid.yaml"]
}
