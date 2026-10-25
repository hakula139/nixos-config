#!/usr/bin/env nu

# ==================================================================================================
# Codex Config Activation
# ==================================================================================================

def save-config [content: string, target: string] {
  let temporary = (^mktemp $"--tmpdir=($target | path dirname)" '.config.XXXXXXXXXX' | str trim)

  try {
    $content | save --force $temporary
    ^chmod 600 $temporary
    ^mv --force $temporary $target
  } catch {|error|
    rm --force $temporary
    error make $error
  }
}

# Mirrors Codex 0.163's `hook_hash` for command handlers without `additionalContextLimit`: the
# SHA-256 of the key-sorted JSON identity of the event, its matcher, and the handler with its
# defaults filled in.
def hook-hash [event: string, matcher: any, handler: record]: nothing -> string {
  let timeout = if $event in [session_end interrupt] {
    [([($handler | get -o timeout | default 1) 3] | math min) 1] | math max
  } else {
    [($handler | get -o timeout | default 600) 1] | math max
  }
  let normalized = {
    type: command
    command: $handler.command
    timeout: $timeout
    async: ($handler | get -o async | default false)
  }
  let status = ($handler | get -o statusMessage)
  let described = if $status == null {
    $normalized
  } else {
    $normalized | insert statusMessage $status
  }
  let identity = {event_name: $event, hooks: [($described | sort)]}
  let keyed = if $matcher == null { $identity } else { $identity | insert matcher $matcher }
  $"sha256:($keyed | sort | to json --raw | hash sha256)"
}

# Codex runs a config hook only after its current hash is recorded as trusted. Every hook comes from
# the managed settings, so activation records each command hook's hash in Codex's state table.
def trust-hooks [hooks: record, state: record, source: string]: nothing -> record {
  $hooks
  | transpose event groups
  | each {|entry|
    let event = ($entry.event | str snake-case)
    # Codex ignores the matcher on these events.
    let matcherless = ($event in [user_prompt_submit stop interrupt])
    $entry.groups | enumerate | each {|group|
      let matcher = if $matcherless { null } else { $group.item | get -o matcher }
      $group.item.hooks | enumerate | where item.type == command | each {|handler|
        {
          key: $"($source):($event):($group.index):($handler.index)"
          hash: (hook-hash $event $matcher $handler.item)
        }
      }
    }
  }
  | flatten
  | flatten
  | reduce --fold $state {|hook, acc|
    let current = ($acc | get -o ([$hook.key] | into cell-path) | default {})
    $acc | upsert ([$hook.key] | into cell-path) ($current | upsert trusted_hash $hook.hash)
  }
}

# Apply managed settings while preserving Codex's mutable user state.
def main [config_file: string, --mcp-only] {
  let config = (open $config_file)
  ^install -d -m 0700 $config.configDir
  let config_dir = ($config.configDir | path expand --strict)
  let target = ($config_dir | path join 'config.toml')

  mut current = if ($target | path exists) {
    open --raw $target | from toml
  } else { {} }

  if $mcp_only {
    save-config ($current | upsert mcp_servers $config.settings.mcp_servers | to toml) $target
    return
  }

  # Native profile files may contain project trust and hook review state.
  if ($config.activeProfile | path exists) {
    let profile = ($config.activeProfile | path expand --strict)
    if ($profile | path dirname) == $config_dir {
      $current = ($current | merge deep --strategy overwrite (open --raw $profile | from toml))
    }
  }

  mut settings = ($current
    | merge deep --strategy overwrite $config.settings
    | merge ($config.settings | select tools mcp_servers hooks))
  let prior_state = ($current | get -o hooks.state | default {})
  let hook_state = (trust-hooks $config.settings.hooks $prior_state $target)
  if not ($hook_state | is-empty) {
    $settings = ($settings | upsert hooks.state $hook_state)
  }

  save-config ($settings | to toml) $target

  if not ($config.keybindings | is-empty) {
    let keybindings_target = ($config_dir | path join 'keybindings.json')
    let current_keybindings = if ($keybindings_target | path exists) {
      open $keybindings_target
    } else { [] }

    let keybindings = ($current_keybindings
      | where {|binding| $binding.command not-in $config.keybindings.command }
      | append $config.keybindings)
    save-config ($keybindings | to json) $keybindings_target
  }
}
