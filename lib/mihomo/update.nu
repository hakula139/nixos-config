#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Update
# ==================================================================================================
# Each run stages the config in its own temporary file, so a start and a timer update cannot collide
# on the rename.
# ==================================================================================================

# Fetch the subscription, merge it under the host base config, and replace the active config.
def main [
  --config: path # Wrapper-supplied JSON with the base config, secret paths, proxy, curl, and rules
] {
  let config = (open $config)
  let target_file = ($config.configDir | path join "config.yaml")

  # The subscription fetch must not loop through mihomo itself, which is either down during initial
  # start or about to be replaced.
  hide-env --ignore-errors ...$config.proxyVars

  print "Fetching mihomo subscription"
  let url = (open --raw $config.subscriptionUrlFile | decode utf-8 | str trim)
  let fetched = (^curl ...$config.curlArgs $url | complete)
  if $fetched.exit_code != 0 {
    print --stderr $"Error: subscription fetch failed with exit ($fetched.exit_code)"
    exit 1
  }
  if ($fetched.stdout | str trim | is-empty) {
    print --stderr "Error: downloaded config is empty"
    exit 1
  }

  print "Preparing subscription rules"
  # A proxied fetch through the nodes the subscription itself defines could never rotate a broken
  # node list, so the subscription host always bypasses the tunnels.
  let subscription_host = ($url | url parse | get -o host | default "")
  let prepended_rules = $config.prependRules ++ (
    if ($subscription_host | is-empty) {
      []
    } else {
      [$"DOMAIN,($subscription_host),DIRECT"]
    }
  )
  let prepared = (
    $fetched.stdout
    | from yaml
    | update rules { $prepended_rules ++ $in }
    | upsert rule-providers { default {} | merge $config.ruleProviders }
  )

  # The base replaces each top-level key it sets, since the ports and DNS belong to the host, and
  # the secret is read here so no store path holds it.
  print "Merging base configuration with subscription"
  let secret = (open --raw $config.secretFile | decode utf-8 | str trim)
  let merged = (
    $prepared
    | merge $config.baseConfig
    | upsert secret $secret
    | to yaml
  )

  let staging_file = (mktemp --tmpdir-path $config.configDir ".config.staging.XXXXXXXXXX")

  try {
    $merged | save --force $staging_file

    # A subscription that is valid YAML but rejected by mihomo would replace a working config and
    # then crash-loop on the next restart.
    let validated = (
      ^mihomo -t
        -d $config.configDir
        -f $staging_file
      | complete
    )
    if $validated.exit_code != 0 {
      let detail = ($"($validated.stdout)\n($validated.stderr)" | str trim)
      error make {msg: $"mihomo rejected the merged config: ($detail)"}
    }

    if ($target_file | path exists) {
      print $"Backing up existing config to ($target_file).bak"
      ^cp $target_file $"($target_file).bak"
    }

    ^mv --force $staging_file $target_file
  } catch {|error|
    rm --force $staging_file
    error make $error
  }

  print "Successfully updated mihomo config"
}
