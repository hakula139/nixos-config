#!/usr/bin/env nu

# ==============================================================================
# Pinned Version Drift Check
# ==============================================================================
# Compare every manually pinned version in this repo against its upstream and
# report which ones have drifted. Renovate-managed pins (flake.lock) are out of
# scope. See SKILL.md for why.
#
# Subcommands:
#   check       Report drift for all pin groups (default)
#   list        Print the pin registry without querying upstreams
# ==============================================================================

const PLUGINS_NIX = "home/modules/llm-assistants/claude-code/plugins.nix"
const CF_IPS_NIX = "modules/nixos/cloudflare/ips.nix"

const CF_IPS_V4_URL = "https://www.cloudflare.com/ips-v4"
const CF_IPS_V6_URL = "https://www.cloudflare.com/ips-v6"

# Abbreviated commit length, matching the trailing comments in plugins.nix.
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
  ^git rev-parse --show-toplevel | str trim
}

# Every upstream query funnels through here so a network failure degrades to an
# empty string, which the caller reports as UNKNOWN rather than as drift.
def query [closure: closure]: nothing -> string {
  try { do $closure | into string | str trim } catch { "" }
}

def abbrev [rev: string]: nothing -> string {
  if ($rev | str length) <= $REV_ABBREV { $rev } else { $rev | str substring 0..<$REV_ABBREV }
}

def gh-api [path: string, jq: string]: nothing -> string {
  query { ^gh api $path --jq $jq }
}

def gh-latest-release [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/releases/latest" ".tag_name"
}

# Upstream's newest release may ship no binaries, which is not a bumpable target.
def gh-latest-release-with-asset [repo: string, asset: string]: nothing -> string {
  gh-api $"repos/($repo)/releases?per_page=100" $"[.[] | select\(.assets | any\(.name == \"($asset)\"\)\)] | first | .tag_name // empty"
}

def gh-default-head [repo: string]: nothing -> string {
  let branch = (gh-api $"repos/($repo)" ".default_branch")
  if ($branch | is-empty) { return "" }
  gh-api $"repos/($repo)/commits/($branch)" ".sha"
}

def gh-latest-semver-tag [repo: string]: nothing -> string {
  query {
    ^gh api $"repos/($repo)/tags?per_page=100"
    | from json
    | get name
    | where {|t| $t =~ '^v?[0-9]+(\.[0-9]+)*$' }
    | first
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

# The trailing comment after `rev` records the release tag this pin points at.
def plugin-tag [root: string, name: string]: nothing -> string {
  plugin-block $root $name
  | str join "\n"
  | parse --regex 'rev = "[0-9a-f]+"; # (?<tag>\S+)'
  | get tag.0?
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
  | where {|p| ($p | path type) == "file" }
  | each {|p| open --raw $p }
  | str join "\n"
  | parse --regex 'uses: (?<pin>[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@v[0-9]+)'
  | get pin
  | uniq
  | sort
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
      title: "Claude Code plugin marketplaces (rev + hash)"
      pins: [
        {
          pin: "agent-browser"
          local: {|| plugin-tag $root "agent-browser" }
          upstream: {|| gh-latest-release "vercel-labs/agent-browser" }
        }
        {
          pin: "openai-codex"
          local: {|| plugin-tag $root "openai-codex" }
          upstream: {|| gh-latest-release "openai/codex-plugin-cc" }
        }
        # These two track a branch, so any newer HEAD counts as drift.
        {
          pin: "claude-plugins-official"
          local: {|| abbrev (plugin-rev $root "claude-plugins-official") }
          upstream: {|| abbrev (gh-default-head "anthropics/claude-plugins-official") }
        }
        {
          pin: "context7-marketplace"
          local: {|| abbrev (plugin-rev $root "context7-marketplace") }
          upstream: {|| abbrev (gh-default-head "upstash/context7") }
        }
        {pin: "anthropic-agent-skills", delegated: "renovate"}
        {pin: "workmux", delegated: "renovate"}
      ]
    }
    {
      title: "Custom packages (packages/)"
      pins: [
        {
          pin: "cloudreve"
          local: {|| nix-version $root "packages/cloudreve/default.nix" }
          upstream: {|| gh-latest-release "cloudreve/cloudreve" }
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
          pin: "zsh-hist"
          local: {|| abbrev (nix-attr $root "packages/zsh-hist/default.nix" 'rev = "(?<v>[0-9a-f]+)"') }
          upstream: {|| abbrev (gh-default-head "marlonrichert/zsh-hist") }
        }
      ]
    }
    {
      title: "Container images (oci-containers image options)"
      pins: [
        {
          pin: "umami"
          local: {|| image-tag $root "modules/nixos/umami/default.nix" }
          upstream: {|| gh-latest-release "umami-software/umami" | str replace -r '^v' '' }
        }
        {
          pin: "fuclaude"
          local: {|| image-tag $root "modules/nixos/fuclaude/default.nix" }
          upstream: {|| dockerhub-latest-semver "pengzhile/fuclaude" }
        }
        {
          pin: "clove"
          local: {|| image-tag $root "modules/nixos/clove/default.nix" }
          upstream: {|| dockerhub-latest-semver "mirrorange/clove" }
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
        {
          pin: "toasty"
          local: {||
            nix-attr $root "home/modules/llm-assistants/shared/notify.nix" 'download/(?<v>v?[0-9.]+)'
          }
          upstream: {|| gh-latest-release-with-asset "shanselman/toasty" "toasty-x64.exe" }
        }
      ]
    }
    {
      title: "GitHub Actions (Renovate github-actions manager is disabled)"
      pins: (action-pins $root | each {|pin|
        let repo = ($pin | split row "@" | first)
        {
          pin: $repo
          local: {|| $pin | split row "@" | last }
          # Actions are pinned to a major tag, so compare only the major component.
          upstream: {|| gh-latest-release $repo | split row "." | first }
        }
      })
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
  if ($pinned | is-empty) or ($fetched | any {|r| $r | is-empty }) { return "" }

  if $pinned == ($fetched | str join "\n" | lines | where $it != "" | sort) {
    "same ranges"
  } else {
    "ranges differ"
  }
}

# ------------------------------------------------------------------------------
# Reporting
# ------------------------------------------------------------------------------

# A pin delegated to Renovate reports its own status, since comparing the two
# `flake.lock` placeholders would otherwise mark it a current manual pin.
def resolve []: list<record> -> list<record> {
  each {|row|
    if ($row.delegated? | is-not-empty) {
      return {pin: $row.pin, pinned: "flake.lock", upstream: "flake.lock", status: $row.delegated}
    }

    let pinned = (do $row.local)
    let upstream = (do $row.upstream)
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

def cmd-list [] {
  print "Manual pins tracked by this script:"
  for group in (registry (repo-root)) {
    print $"\n($group.title)"
    for pin in $group.pins { print $"  ($pin.pin)" }
  }
  print "\nRenovate covers the 13 flake.lock inputs separately."
}

def cmd-check [] {
  if (which gh | is-empty) {
    die 'gh not found. Run inside "nix develop" or install it.'
  }
  if ((^gh auth status | complete).exit_code != 0) {
    die 'gh is not authenticated. Run "gh auth login".'
  }

  let all = registry (repo-root) | each {|group|
    let rows = if ($group.pins | is-empty) {
      # An empty group would print as a clean sweep, which is indistinguishable
      # from every pin being current.
      [{pin: $group.title, pinned: "?", upstream: "?", status: "UNKNOWN"}]
    } else {
      $group.pins | resolve
    }
    section $group.title $rows
    $rows
  } | flatten

  let stale = ($all | where status == "STALE" | length)
  let unknown = ($all | where status == "UNKNOWN" | length)

  print $"\n($stale) stale, ($unknown) unknown."
  if $unknown > 0 {
    print "UNKNOWN means the upstream query failed. Re-check those by hand."
    exit 2
  }
  if $stale > 0 { exit 1 }
}

def main [subcommand: string = "check"] {
  match $subcommand {
    "check" => { cmd-check }
    "list" => { cmd-list }
    _ => { die $"unknown subcommand: ($subcommand)" }
  }
}
