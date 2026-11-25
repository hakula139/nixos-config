#!/usr/bin/env nu

# ==================================================================================================
# Managed Hosts Updater
# ==================================================================================================

use config-file.nu [save-atomic]

const HOSTS_PREFIX = "# nixos-config:"

# Return `$raw` with lines tagged `# nixos-config: <owner>` replaced in place.
export def rewrite-hosts [raw: string, owner: string, entries: list<string>]: nothing -> string {
  let tagged = (
    $entries
    | where { ($in | str trim) != "" }
    | each { $"($in) ($HOSTS_PREFIX) ($owner)" }
  )

  let has_trailing_nl = ($raw | str ends-with (char nl))
  let raw_lines = if ($raw | is-empty) {
    []
  } else if $has_trailing_nl {
    $raw | str substring 0..-2 | split row (char nl)
  } else {
    $raw | split row (char nl)
  }

  let owner_pattern = ('(?:^|\s)' + $HOSTS_PREFIX + " " + $owner + '[ \t]*\r?$')

  mut out: list<string> = []
  mut inserted = false
  mut appended_at_end = false

  for line in $raw_lines {
    if ($line =~ $owner_pattern) {
      if (not $inserted) and ($tagged | is-not-empty) {
        $out = ($out | append $tagged)
        $inserted = true
      }
    } else {
      $out = ($out | append $line)
    }
  }

  if (not $inserted) and ($tagged | is-not-empty) {
    $out = ($out | append $tagged)
    $appended_at_end = true
  }

  if ($out | is-empty) {
    return ""
  }

  let body = ($out | str join (char nl))
  if $appended_at_end or $has_trailing_nl {
    $"($body)(char nl)"
  } else {
    $body
  }
}

# Update managed entries in a hosts file atomically from a JSON config file.
def main [
  --config: path # JSON config with hostsFile, owner, entries, and optional group
] {
  let cfg = (open --raw $config | from json)
  let target = $cfg.hostsFile
  let raw = (open --raw $target | default "")
  let updated = (rewrite-hosts $raw $cfg.owner $cfg.entries)

  if $updated == $raw {
    return
  }

  if $cfg.group? != null {
    save-atomic $updated $target --mode "0644" --owner $"root:($cfg.group)"
  } else {
    save-atomic $updated $target --mode "0644"
  }
}
