#!/usr/bin/env nu

# ==============================================================================
# Pinned Version Drift Check
# ==============================================================================
# Compare the registered manual pins against their upstream values and report
# which ones have drifted. Renovate-managed pins (flake.lock) are out of
# scope. See ../SKILL.md for why.
#
# Run with `--help` for usage.
# ==============================================================================

const PLUGINS_NIX = "home/modules/llm-assistants/claude-code/plugins.nix"
const CF_IPS_NIX = "modules/nixos/cloudflare/ips.nix"

const CF_IPS_V4_URL = "https://www.cloudflare.com/ips-v4"
const CF_IPS_V6_URL = "https://www.cloudflare.com/ips-v6"

# Commit prefix length used by the plugin bundle.
const REV_ABBREV = 12

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# A missing prerequisite leaves the run incomplete, so it shares exit 2 with a
# failed upstream query.
def die [msg: string] {
  print -e $"error: ($msg)"
  exit 2
}

def repo-root []: nothing -> string {
  try { ^git rev-parse --show-toplevel | str trim } catch {
    die "cannot find the repository root. Run inside the nixos-config checkout."
  }
}

# A failed lookup leaves no comparable value, so the caller reports UNKNOWN.
def query [closure: closure]: nothing -> string {
  try { do $closure | into string | str trim } catch { "" }
}

def abbrev [rev: string]: nothing -> string {
  if ($rev | str length) <= $REV_ABBREV { $rev } else { $rev | str substring 0..<$REV_ABBREV }
}

def gh-api [path: string, jq: string]: nothing -> string {
  query { ^gh api --hostname github.com $path --jq $jq }
}

def gh-latest-release [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/releases/latest" ".tag_name"
}

def gh-latest-release-head [repo: string]: nothing -> string {
  let tag = (gh-latest-release $repo)
  if ($tag | is-empty) {
    return ""
  }
  gh-api $"repos/($repo)/commits/($tag)" ".sha"
}

# Upstream's newest release may ship no binaries, which is not a bumpable target.
def gh-latest-release-with-asset [repo: string, asset: string]: nothing -> string {
  gh-api $"repos/($repo)/releases?per_page=100" $"[.[] | select\(.assets | any\(.name == \"($asset)\"\)\)] | first | .tag_name // empty"
}

def gh-default-head [repo: string]: nothing -> string {
  let branch = (gh-api $"repos/($repo)" ".default_branch")
  if ($branch | is-empty) {
    return ""
  }
  gh-api $"repos/($repo)/commits/($branch)" ".sha"
}

def gh-latest-semver-tag [repo: string]: nothing -> string {
  query {
    gh-api $"repos/($repo)/tags?per_page=100" ".[].name"
    | lines
    | where {|t| $t =~ '^v?[0-9]+(\.[0-9]+)*$' }
    | sort-by {|tag| $tag | str replace -r '^v' '' | split row "." | each {|n| $n | into int } }
    | last
  }
}

def dockerhub-latest-semver [repo: string]: nothing -> string {
  query {
    http get $"https://hub.docker.com/v2/repositories/($repo)/tags?page_size=100"
    | get results.name
    | where {|n| $n =~ '^[0-9]+\.[0-9]+\.[0-9]+$' }
    | sort-by {|n| $n | split row "." | each {|p| $p | into int } }
    | last
  }
}

def npm-latest [pkg: string]: nothing -> string {
  query { http get $"https://registry.npmjs.org/($pkg)/latest" | get version }
}

def pypi-latest [pkg: string]: nothing -> string {
  query { http get $"https://pypi.org/pypi/($pkg)/json" | get info.version }
}

# ------------------------------------------------------------------------------
# Pin extraction
# ------------------------------------------------------------------------------

def plugin-block [root: string, name: string]: nothing -> list<string> {
  open --raw ([$root $PLUGINS_NIX] | path join)
  | lines
  | skip until {|l| $l == $"    ($name) = {" }
  | take until {|l| $l == "    };" }
}

def plugin-rev [root: string, name: string]: nothing -> string {
  plugin-block $root $name
  | str join "\n"
  | parse --regex 'rev = "(?<rev>[0-9a-f]+)"'
  | get rev.0?
  | default ""
}

def nix-attr [root: string, file: string, regex: string]: nothing -> string {
  open --raw ([$root $file] | path join) | parse --regex $regex | get v.0? | default ""
}

def nix-version [root: string, file: string]: nothing -> string {
  nix-attr $root $file '(?m)^\s*version = "(?<v>[^"]+)"'
}

# Stays empty on extraction failure, so a broken pattern reports UNKNOWN.
def nix-version-v [root: string, file: string]: nothing -> string {
  let v = (nix-version $root $file)
  if ($v | is-empty) { "" } else { $"v($v)" }
}

def image-tag [root: string, file: string]: nothing -> string {
  open --raw ([$root $file] | path join)
  | lines
  | skip until {|l| $l =~ 'image = lib.mkOption' }
  | take until {|l| $l =~ '^\s*};\s*$' }
  | str join "\n"
  | parse --regex 'default = "[^"]*:(?<v>[^"]+)"'
  | get v.0?
  | default ""
}

def action-pins [root: string]: nothing -> list<string> {
  [".github/workflows" ".github/actions"]
  | each {|dir| glob ([$root $dir "**" "*"] | path join) }
  | flatten
  | where {|p|
    ($p | path type) == "file" and ($p | path parse | get extension) in [yml yaml]
  }
  | each {|p|
    let doc = (open $p)
    let jobs = ($doc | get -o jobs | default {} | values)
    [
      ($jobs | get -o uses)
      ($jobs | each {|job| $job | get -o steps | default [] | get -o uses } | flatten)
      ($doc | get -o runs.steps | default [] | get -o uses)
    ]
    | flatten
  }
  | flatten
  | compact
  | where {|pin|
    not ($pin | str starts-with "./") and not ($pin | str starts-with "docker://")
  }
  | uniq
  | sort
}

# ------------------------------------------------------------------------------
# Cloudflare comparison
# ------------------------------------------------------------------------------

# The IP list carries no version, so drift means the ranges themselves differ.
def cloudflare-drift [root: string]: nothing -> string {
  let pinned = (
    open --raw ([$root $CF_IPS_NIX] | path join)
    | parse --regex '"(?<v>[0-9a-f.:]+/[0-9]+)'
    | get v
    | sort
  )
  let fetched = (
    [$CF_IPS_V4_URL $CF_IPS_V6_URL]
    | each {|url| query { http get --raw $url } }
  )

  # An empty half would otherwise surface as drift against the half we did fetch.
  if ($pinned | is-empty) or ($fetched | any {|r| $r | is-empty }) {
    return ""
  }

  if $pinned == ($fetched | str join "\n" | lines | where $it != "" | sort) {
    "same ranges"
  } else {
    "ranges differ"
  }
}

# ------------------------------------------------------------------------------
# Pin registry
# ------------------------------------------------------------------------------

# Each row pairs a pin name with closures that read the local value and the
# upstream value. Both stay lazy so `list` can print the registry without
# touching the network.
def registry [root: string]: nothing -> list<record> {
  [
    {
      title: "Versioned flake input refs"
      pins: [
        {
          pin: "listenbrainz-scrobbler"
          local: {||
            nix-attr $root "flake.nix" 'github:hakula139/listenbrainz-scrobbler/(?<v>[^"]+)'
          }
          upstream: {|| gh-latest-release "hakula139/listenbrainz-scrobbler" }
        }
      ]
    }
    {
      title: "Claude Code plugin marketplaces (rev + hash)"
      pins: [
        {
          pin: "openai-codex"
          local: {|| abbrev (plugin-rev $root "openai-codex") }
          upstream: {|| abbrev (gh-latest-release-head "openai/codex-plugin-cc") }
        }
        {
          pin: "claude-plugins-official"
          local: {|| abbrev (plugin-rev $root "claude-plugins-official") }
          upstream: {|| abbrev (gh-default-head "anthropics/claude-plugins-official") }
        }
        {pin: "workmux", delegated: "renovate"}
      ]
    }
    {
      title: "Nix-built overlay packages"
      pins: [
        {
          pin: "acpx"
          local: {|| nix-version-v $root "packages/acpx/default.nix" }
          upstream: {|| gh-latest-release "openclaw/acpx" }
        }
        {
          pin: "cloudreve"
          local: {|| nix-version $root "packages/cloudreve/default.nix" }
          upstream: {|| gh-latest-release "cloudreve/cloudreve" }
        }
        {
          pin: "mcp-server-filesystem"
          local: {|| nix-version $root "packages/mcp/mcp-server-filesystem/default.nix" }
          upstream: {|| gh-latest-semver-tag "modelcontextprotocol/servers" }
        }
        {
          pin: "mcp-server-git"
          local: {|| nix-version $root "packages/mcp/mcp-server-git/default.nix" }
          upstream: {|| pypi-latest "mcp-server-git" }
        }
        {
          pin: "mcp-server-github"
          local: {|| nix-version-v $root "packages/mcp/mcp-server-github/default.nix" }
          upstream: {|| gh-latest-release "github/github-mcp-server" }
        }
        {
          pin: "mcp-server-gitlab"
          local: {|| nix-version-v $root "packages/mcp/mcp-server-gitlab/default.nix" }
          upstream: {|| gh-latest-release "zereight/gitlab-mcp" }
        }
        {
          pin: "zsh-hist"
          local: {|| abbrev (nix-attr $root "packages/zsh-hist/default.nix" 'rev = "(?<v>[0-9a-f]+)"') }
          upstream: {|| abbrev (gh-default-head "marlonrichert/zsh-hist") }
        }
      ]
    }
    {
      title: "Windows notification helper"
      pins: [
        {
          pin: "toasty"
          local: {||
            nix-attr $root "home/modules/llm-assistants/shared/notify/default.nix" 'download/(?<v>v?[0-9.]+)'
          }
          upstream: {|| gh-latest-release-with-asset "shanselman/toasty" "toasty-x64.exe" }
        }
      ]
    }
    {
      title: "Container images (oci-containers image options)"
      pins: [
        {
          pin: "clove"
          local: {|| image-tag $root "modules/nixos/clove/default.nix" }
          upstream: {|| dockerhub-latest-semver "mirrorange/clove" }
        }
        {
          pin: "fuclaude"
          local: {|| image-tag $root "modules/nixos/fuclaude/default.nix" }
          upstream: {|| dockerhub-latest-semver "pengzhile/fuclaude" }
        }
        {
          pin: "umami"
          local: {|| image-tag $root "modules/nixos/umami/default.nix" }
          upstream: {|| gh-latest-release "umami-software/umami" | str replace -r '^v' '' }
        }
      ]
    }
    {
      title: "Runtime-installed packages"
      pins: [
        {
          pin: "piclist"
          local: {|| nix-version $root "modules/nixos/piclist/server/default.nix" }
          upstream: {|| npm-latest "piclist" }
        }
      ]
    }
    {
      title: "GitHub Actions (Renovate github-actions manager is disabled)"
      pins: (try {
        action-pins $root | each {|pin|
          # GitHub repository action or reusable workflow, with an optional subpath.
          let target = ($pin | parse -r '^(?<repo>[^/]+/[^/@]+)(?:/[^@]+)?@(?<ref>[^@]+)$' | first)
          {
            pin: ($pin | split row "@" | first)
            local: {|| $target.ref }
            upstream: {||
              if $target.ref =~ '^v[0-9]+$' {
                gh-latest-release $target.repo | split row "." | first
              } else if $target.ref =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' {
                gh-latest-release $target.repo
              } else {
                ""
              }
            }
          }
        }
      } catch { [] })
    }
    {
      title: "Drifting upstream data"
      pins: [
        {
          pin: "cloudflare-ips"
          local: {|| nix-attr $root $CF_IPS_NIX 'Last updated: (?<v>\S+)' }
          upstream: {|| cloudflare-drift $root }
          # The pinned column is a date and the upstream column a verdict, so
          # the two are not comparable.
          status: {|upstream| match $upstream { "same ranges" => "ok", _ => "STALE" } }
        }
      ]
    }
  ]
}

# ------------------------------------------------------------------------------
# Reporting
# ------------------------------------------------------------------------------

# A pin delegated to Renovate reports its own status, since comparing the two
# `flake.lock` placeholders would otherwise mark it a current manual pin.
# Every pin is an independent network round trip, so they resolve concurrently.
def resolve []: list<record> -> list<record> {
  par-each --keep-order {|row|
    if ($row.delegated? | is-not-empty) {
      return {pin: $row.pin, pinned: "flake.lock", upstream: "flake.lock", status: $row.delegated}
    }

    let pinned = (query $row.local)
    let upstream = (query $row.upstream)
    let status = if ($pinned | is-empty) or ($upstream | is-empty) {
      "UNKNOWN"
    } else if ($row.status? | is-not-empty) {
      do $row.status $upstream
    } else if $pinned == $upstream {
      "ok"
    } else {
      "STALE"
    }

    {
      pin: $row.pin
      pinned: (if ($pinned | is-empty) { "?" } else { $pinned })
      upstream: (if ($upstream | is-empty) { "?" } else { $upstream })
      status: $status
    }
  }
}

def section [title: string, rows: list<record>] {
  print $"\n($title)"
  print ($rows | table)
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

# Compare registered manual pins with upstream versions.
def "main check" [] {
  if (which gh | is-empty) {
    die "gh not found. Install GitHub CLI and authenticate to github.com."
  }
  if ((^gh auth status --hostname github.com | complete).exit_code != 0) {
    die "GitHub authentication check failed. Check credentials and network access."
  }

  # Resolution finishes before anything prints, since `par-each` threads would
  # otherwise interleave their sections.
  let groups = (
    registry (repo-root)
    | par-each --keep-order {|group|
      let rows = if ($group.pins | is-empty) {
        # An empty group would print as a clean sweep, which is indistinguishable
        # from every pin being current.
        [{pin: $group.title, pinned: "?", upstream: "?", status: "UNKNOWN"}]
      } else {
        $group.pins | resolve
      }
      {title: $group.title, rows: $rows}
    }
  )

  for group in $groups {
    section $group.title $group.rows
  }
  let all = ($groups | get rows | flatten)

  let stale = ($all | where status == "STALE" | length)
  let unknown = ($all | where status == "UNKNOWN" | length)

  print $"\n($stale) stale, ($unknown) unknown."
  if $unknown > 0 {
    print "UNKNOWN means extraction or an upstream query failed. Re-check those by hand."
    exit 2
  }
  if $stale > 0 {
    exit 1
  }
}

# List the registered pins without querying upstream.
def "main list" [] {
  print "Manual pins tracked by this script:"
  for group in (registry (repo-root)) {
    print $"\n($group.title)"
    for pin in $group.pins { print $"  ($pin.pin)" }
  }
  print "\nRenovate updates flake.lock separately within the configured input refs."
}

# Check registered manual pins for upstream drift by default.
def main [] {
  main check
}
