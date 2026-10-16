#!/usr/bin/env nu

# ==================================================================================================
# Xray Config Renderer Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join render-config.nu)

const USERS = {
  alice: {uuid: alice-uuid, shortId: a1, level: admin}
  bob: {uuid: bob-uuid, shortId: b2, level: user}
  carol: {uuid: carol-uuid, shortId: c3}
}

const SETTINGS = {
  inbounds: [
    {
      tag: vless-reality
      settings: {decryption: none}
      streamSettings: {security: reality, realitySettings: {dest: "127.0.0.1:8443"}}
    }
    {
      tag: vless-ws
      settings: {decryption: none}
      streamSettings: {network: ws}
    }
  ]
  outbounds: [{protocol: freedom}]
}

def render [min_level: string]: nothing -> record {
  let dir = (mktemp --directory)
  let users_file = ($dir | path join users.json)
  let key_file = ($dir | path join private-key)
  let config_file = ($dir | path join render.json)
  let output = ($dir | path join config.json)

  $USERS | to json | save $users_file
  "private-key\n" | save $key_file
  {
    settings: $SETTINGS
    clientFlows: {vless-reality: xtls-rprx-vision}
    minLevel: $min_level
    usersFile: $users_file
    privateKeyFile: $key_file
    outputFile: $output
  }
  | to json
  | save $config_file

  let run = (^$nu.current-exe --no-config-file $SCRIPT $config_file | complete)
  {run: $run, output: $output}
}

def "test an admin server admits only admins" [] {
  let result = (render admin)
  assert equal $result.run.exit_code 0

  let config = (open $result.output)
  let reality = ($config.inbounds | where tag == vless-reality | first)
  let ws = ($config.inbounds | where tag == vless-ws | first)
  assert equal $reality.settings.clients [{id: alice-uuid, flow: xtls-rprx-vision}]
  assert equal $reality.streamSettings.realitySettings {
    dest: "127.0.0.1:8443"
    privateKey: private-key
    shortIds: [a1]
  }
  assert equal $ws.settings.clients [{id: alice-uuid}]
  assert equal $ws.streamSettings {network: ws}
  assert equal $config.outbounds $SETTINGS.outbounds
  assert equal (ls -l $result.output | get 0.mode) "rw-------"
}

def "test a user server admits every level, reading a missing level as user" [] {
  let result = (render user)
  assert equal $result.run.exit_code 0

  let reality = (open $result.output | get inbounds | where tag == vless-reality | first)
  assert equal ($reality.settings.clients | get id | sort) [alice-uuid bob-uuid carol-uuid]
  assert equal ($reality.streamSettings.realitySettings.shortIds | sort) [a1 b2 c3]
}

def "test an unknown minimum level fails without writing a config" [] {
  let result = (render owner)

  assert not equal $result.run.exit_code 0
  assert not ($result.output | path exists)
}
