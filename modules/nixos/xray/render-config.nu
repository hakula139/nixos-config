#!/usr/bin/env nu

# ==================================================================================================
# Xray Config Renderer
# ==================================================================================================

const LEVELS = [user admin]

# Fill an inbound's clients, adding REALITY short IDs and the private key to a REALITY inbound.
def render-inbound [
  inbound: record
  users: list<record>
  flow: any
  private_key: string
]: nothing -> record {
  let clients = (
    $users
    | each {|user|
      if $flow == null { {id: $user.uuid} } else { {id: $user.uuid, flow: $flow} }
    }
  )
  let inbound = ($inbound | upsert settings.clients $clients)

  if $inbound.streamSettings.security? != "reality" {
    return $inbound
  }
  $inbound
  | upsert streamSettings.realitySettings.privateKey $private_key
  | upsert streamSettings.realitySettings.shortIds ($users | get shortId)
}

# Render the Xray config, admitting proxy users whose level meets this server's minimum.
def main [config_file: string] {
  let config = (open $config_file)
  if $config.minLevel not-in $LEVELS {
    error make {msg: $"Unknown minimum level: ($config.minLevel)"}
  }

  let allowed_levels = ($LEVELS | skip until {|level| $level == $config.minLevel })
  let users = (
    open --raw $config.usersFile
    | from json
    | values
    | where {|user| ($user.level? | default "user") in $allowed_levels }
  )
  let private_key = (open --raw $config.privateKeyFile | decode utf-8 | str trim)

  let inbounds = (
    $config.settings.inbounds
    | each {|inbound|
      let flow = ($config.clientFlows | get -o $inbound.tag)
      render-inbound $inbound $users $flow $private_key
    }
  )

  $config.settings
  | upsert inbounds $inbounds
  | to json
  | save --force $config.outputFile
  ^chmod 600 $config.outputFile

  print $"Rendered Xray config for ($users | length) users at level ($config.minLevel) or above"
}
