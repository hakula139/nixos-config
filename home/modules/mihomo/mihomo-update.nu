#!/usr/bin/env nu

def main [
  --config: path # Wrapper-supplied JSON with the base config, secret files, proxy, curl args, and added rules
] {
  let config = (open $config)
  let target_file = ($config.configDir | path join "config.yaml")
  let staging_file = ($config.configDir | path join "config.staging.yaml")

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
  let prepared = (
    $fetched.stdout
    | from yaml
    | update rules { $config.prependRules ++ $in }
    | upsert rule-providers { default {} | merge $config.ruleProviders }
  )

  # The base replaces each top-level key it sets, since the ports and DNS belong to the host, and the
  # secret is read here so no store path holds it.
  print "Merging base configuration with subscription"
  let secret = (open --raw $config.secretFile | decode utf-8 | str trim)
  let merged = (
    $prepared
    | merge $config.baseConfig
    | upsert secret $secret
    | to yaml
  )

  $merged | save --force $staging_file

  if ($target_file | path exists) {
    print $"Backing up existing config to ($target_file).bak"
    ^cp $target_file $"($target_file).bak"
  }

  mv --force $staging_file $target_file
  print "Successfully updated mihomo config"
}
