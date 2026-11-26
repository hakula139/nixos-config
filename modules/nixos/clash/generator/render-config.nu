#!/usr/bin/env nu

# ==================================================================================================
# Clash Subscription Config Renderer
# ==================================================================================================

use config-file.nu [save-atomic]

# Parse and validate a single user entry from users.json, returning null when skipped.
def parse-user [entry: any, valid_levels: list<string>]: nothing -> any {
  if not ($entry | describe | str starts-with "record") {
    print --stderr "Skipping malformed user entry"
    return null
  }

  let name = $entry.name?
  let uuid = $entry.uuid?
  let short_id = $entry.shortId?
  if ($name | describe) != "string" or ($name | is-empty) {
    print --stderr "Skipping user entry missing required field: name"
    return null
  }
  if ($uuid | describe) != "string" or ($uuid | is-empty) or ($short_id | describe) != "string" {
    print --stderr $"Skipping user ($name): missing required fields uuid or shortId"
    return null
  }

  let raw_level = ($entry.level? | default "user")
  if ($raw_level | describe) != "string" {
    print --stderr $"Skipping user ($name): non-string level"
    return null
  }
  let level = ($raw_level | str lowercase)
  if $level not-in $valid_levels {
    print --stderr $"Skipping user ($name): unknown level '($raw_level)'"
    return null
  }

  {
    name: $name
    uuid: $uuid
    shortId: $short_id
    level: $level
  }
}

# Read and validate users from users.json.
def load-users [path: path, valid_levels: list<string>]: nothing -> list<record> {
  if not ($path | path exists) {
    print --stderr $"Users file not found at ($path)"
    return []
  }

  let data = (
    try {
      open --raw $path | into string | from json
    } catch {|err|
      print --stderr $"Invalid JSON in users file: ($err.msg)"
      null
    }
  )
  if $data == null {
    return []
  }

  let users_raw = if ($data | describe | str starts-with "record") { $data.users? } else { null }
  let kind = ($users_raw | describe)
  if not (($kind | str starts-with "list") or ($kind | str starts-with "table")) {
    print --stderr 'Users file must contain an object with a "users" array'
    return []
  }

  $users_raw
  | each {|entry| parse-user $entry $valid_levels }
  | compact
  | reduce --fold {} {|user, acc| $acc | upsert $user.name $user }
  | values
}

# Build a user's Clash subscription record by injecting credentials into level proxies.
def render-subscription [config: record, user: record]: nothing -> record {
  let level = ($config.levels | get $user.level)
  let proxies = (
    $level.proxies
    | each {|proxy|
      let proxy = ($proxy | upsert uuid $user.uuid)
      if "reality-opts" in $proxy {
        $proxy | upsert reality-opts.short-id $user.shortId
      } else {
        $proxy
      }
    }
  )

  {
    proxies: $proxies
    proxy-groups: $level.proxy-groups
    rule-providers: $config.rule-providers
    rules: $config.rules
  }
}

# Remove .yaml subscription files in output_dir that do not belong to any current user.
def prune-stale [output_dir: path, users: list<record>]: nothing -> nothing {
  let current = ($users | each {|user| $"($user.uuid).yaml" })
  ls $output_dir
  | where type == "file"
  | get name
  | where {|file|
    let base = ($file | path basename)
    ($base | str ends-with ".yaml") and ($base not-in $current)
  }
  | each {|file|
    rm $file
    print $"Removed stale Clash subscription ($file | path basename)"
  }
  | ignore
}

# Render per-user Clash subscription YAML files and prune stale outputs.
def main [
  --config: path # Wrapper-supplied JSON with level templates, rules, users file, and output dir
] {
  let config = (open $config)
  let users = (load-users $config.usersFile ($config.levels | columns))
  if ($users | is-empty) {
    exit 1
  }

  for user in $users {
    let output_path = ($config.outputDir | path join $"($user.uuid).yaml")
    save-atomic (render-subscription $config $user | to yaml) $output_path --mode "0640"
  }

  prune-stale $config.outputDir $users
  print $"Generated Clash subscriptions for ($users | length) users"
}
