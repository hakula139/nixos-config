#!/usr/bin/env nu

# ==================================================================================================
# Clash Subscription Generator Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .

const SERVERS = [
  {id: sg-1, level: user}
  {id: us-2, level: user}
  {id: us-1, level: admin}
]

# Run the generator over `users` into an output directory that already holds a stale subscription.
def generate [users: record]: nothing -> record {
  let dir = (mktemp --directory)
  let output = ($dir | path join out)
  mkdir $output
  "stale" | save ($output | path join stale-uuid.yaml)
  $users | to json | save ($dir | path join users.json)
  $SERVERS | to json | save ($dir | path join servers.json)

  let run = (
    ^python3 ($SCRIPT_DIR | path join generator.py)
      --users-path ($dir | path join users.json)
      --servers-path ($dir | path join servers.json)
      --template-path ($SCRIPT_DIR | path join template.yaml.j2)
      --sni-host sni.example.com
      --output-dir $output
    | complete
  )
  {run: $run, output: $output}
}

def subscription [output: string, uuid: string]: nothing -> record {
  open ($output | path join $"($uuid).yaml")
}

def "test each user gets the servers their level admits" [] {
  let result = (generate {
    alice: {uuid: alice-uuid, shortId: a1, level: admin}
    bob: {uuid: bob-uuid, shortId: b2}
    eve: {uuid: eve-uuid, shortId: e5, level: root}
  })
  assert equal $result.run.exit_code 0 $result.run.stderr

  let alice = (subscription $result.output alice-uuid)
  assert equal ($alice.proxies | where network == tcp | get server) [
    us-1.hakula.xyz
    us-2.hakula.xyz
    sg-1.hakula.xyz
  ]
  assert equal ($alice.proxies | get uuid | uniq) [alice-uuid]
  assert equal ($alice.proxies | where network == tcp | get reality-opts.short-id | uniq) [a1]
  assert equal ($alice.proxies | where network == tcp | get servername | uniq) [sni.example.com]
  assert equal ($alice.proxy-groups.0.proxies) ($alice.proxies | get name)

  let bob = (subscription $result.output bob-uuid)
  assert equal ($bob.proxies | where network == tcp | get server) [us-2.hakula.xyz sg-1.hakula.xyz]

  # A user with an unknown level is skipped, and subscriptions for departed users are removed.
  assert equal (ls $result.output | get name | path basename | sort) [alice-uuid.yaml bob-uuid.yaml]
  # Subscriptions carry credentials.
  assert equal (ls -l ($result.output | path join alice-uuid.yaml) | get 0.mode) "rw-r-----"
}

def "test no valid users fails and keeps existing subscriptions" [] {
  let result = (generate {eve: {uuid: eve-uuid, level: admin}})
  assert not equal $result.run.exit_code 0
  assert equal (ls $result.output | get name | path basename) [stale-uuid.yaml]
}
