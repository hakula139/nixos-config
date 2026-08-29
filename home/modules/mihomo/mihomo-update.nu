#!/usr/bin/env nu

# Fetch the mihomo subscription and merge it into the base configuration.

const CURL = "@curl@"
const BASE_CONFIG_FILE = "@baseConfigFile@"
const CONFIG_DIR = "@configDir@"
const SECRET_FILE = "@secretFile@"
const SUBSCRIPTION_URL_FILE = "@subscriptionUrlFile@"

# `$e.msg` is always "Error while parsing as yaml", so the key comes from $e.rendered.
def yaml_error [e: record]: nothing -> string {
    let marker = "Could not load YAML: "
    let hit = ($e.rendered | lines | where ($it | str contains $marker) | get -o 0)
    if ($hit | is-empty) {
        return $e.msg
    }
    $hit | str substring (($hit | str index-of $marker) + ($marker | str length))..
}

def main [] {
    let config_file = ($CONFIG_DIR | path join "config.yaml")

    # `open` only parses YAML when the extension says so, and the named
    # duplicate-key error is worth more than a generic one.
    let staging_file = ($CONFIG_DIR | path join "config.staging.yaml")

    mkdir $CONFIG_DIR

    # The subscription fetch must not loop through mihomo itself, which is
    # either down (initial start) or about to be replaced.
    hide-env --ignore-errors @proxyVars@

    print "Fetching mihomo subscription"
    let url = (open --raw $SUBSCRIPTION_URL_FILE | decode utf-8 | str trim)
    let fetched = (^$CURL -fsSL $url | complete)
    if $fetched.exit_code != 0 {
        print --stderr $"Error: subscription fetch failed with exit ($fetched.exit_code)"
        exit 1
    }
    if ($fetched.stdout | str trim | is-empty) {
        print --stderr "Error: downloaded config is empty"
        exit 1
    }

    # `str replace` is literal in both pattern and replacement, so `|`, `&`,
    # `\` and `'` survive. The base config holds the secret in a single-quoted
    # scalar, so a literal `'` still has to be doubled for YAML itself.
    print "Preparing base configuration with secrets"
    let secret = (open --raw $SECRET_FILE | decode utf-8 | str trim | str replace --all "'" "''")
    let base = (open --raw $BASE_CONFIG_FILE | decode utf-8 | str replace --all "__SECRET__" $secret)

    print "Merging base configuration with subscription"
    $"($base)\n($fetched.stdout)" | save --force $staging_file

    print "Validating merged config"
    try {
        open $staging_file | ignore
    } catch { |e|
        rm --force $staging_file
        print --stderr $"Error: merged config is not valid YAML, keeping previous config: (yaml_error $e)"
        exit 1
    }

    if ($config_file | path exists) {
        print $"Backing up existing config to ($config_file).bak"
        cp $config_file $"($config_file).bak"
    }

    mv --force $staging_file $config_file
    print "Successfully updated mihomo config"
}
