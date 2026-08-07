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

# Returns the lines of a `<name> = { ... };` block from plugins.nix.
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
# Pin groups
# ------------------------------------------------------------------------------

# Each check returns rows of {pin, pinned, upstream} or an explicit status.
# `status` is derived in `classify` so every group shares one rule.

def check-plugins [root: string]: nothing -> list<record> {
  let released = [
    [name repo];
    [agent-browser vercel-labs/agent-browser]
    [openai-codex openai/codex-plugin-cc]
  ]
  | each {|e|
    {pin: $e.name, pinned: (plugin-tag $root $e.name), upstream: (gh-latest-release $e.repo)}
  }

  # These two track a branch, so any newer HEAD counts as drift.
  let branched = [
    [name repo];
    [claude-plugins-official anthropics/claude-plugins-official]
    [context7-marketplace upstash/context7]
  ]
  | each {|e|
    {
      pin: $e.name
      pinned: (abbrev (plugin-rev $root $e.name))
      upstream: (abbrev (gh-default-head $e.repo))
    }
  }

  $released
  | append $branched
  | append [
    {pin: "anthropic-agent-skills", pinned: "flake.lock", upstream: "flake.lock", status: "renovate"}
    {pin: "workmux", pinned: "flake.lock", upstream: "flake.lock", status: "renovate"}
  ]
}

def check-packages [root: string]: nothing -> list<record> {
  [
    {
      pin: "cloudreve"
      pinned: (nix-version $root "packages/cloudreve/default.nix")
      upstream: (gh-latest-release "cloudreve/cloudreve")
    }
    {
      pin: "mcp-server-github"
      pinned: (nix-version-v $root "packages/mcp/mcp-server-github/default.nix")
      upstream: (gh-latest-release "github/github-mcp-server")
    }
    {
      pin: "mcp-server-gitlab"
      pinned: (nix-version-v $root "packages/mcp/mcp-server-gitlab/default.nix")
      upstream: (gh-latest-release "zereight/gitlab-mcp")
    }
    {
      pin: "mcp-server-filesystem"
      pinned: (nix-version $root "packages/mcp/mcp-server-filesystem/default.nix")
      upstream: (gh-latest-semver-tag "modelcontextprotocol/servers")
    }
    {
      pin: "mcp-server-git"
      pinned: (nix-version $root "packages/mcp/mcp-server-git/default.nix")
      upstream: (pypi-latest "mcp-server-git")
    }
    {
      pin: "zsh-hist"
      pinned: (abbrev (nix-attr $root "packages/zsh-hist/default.nix" 'rev = "(?<v>[0-9a-f]+)"'))
      upstream: (abbrev (gh-default-head "marlonrichert/zsh-hist"))
    }
  ]
}

def check-containers [root: string]: nothing -> list<record> {
  [
    {
      pin: "umami"
      pinned: (image-tag $root "modules/nixos/umami/default.nix")
      upstream: (gh-latest-release "umami-software/umami" | str replace -r '^v' '')
    }
    {
      pin: "fuclaude"
      pinned: (image-tag $root "modules/nixos/fuclaude/default.nix")
      upstream: (dockerhub-latest-semver "pengzhile/fuclaude")
    }
    {
      pin: "clove"
      pinned: (image-tag $root "modules/nixos/clove/default.nix")
      upstream: (dockerhub-latest-semver "mirrorange/clove")
    }
  ]
}

def check-runtime [root: string]: nothing -> list<record> {
  [
    {
      pin: "piclist"
      pinned: (nix-version $root "modules/nixos/piclist/server/default.nix")
      upstream: (npm-latest "piclist")
    }
    {
      pin: "toasty"
      pinned: (
        nix-attr $root "home/modules/llm-assistants/shared/notify.nix" 'download/(?<v>v?[0-9.]+)'
      )
      upstream: (gh-latest-release-with-asset "shanselman/toasty" "toasty-x64.exe")
    }
  ]
}

def check-actions [root: string]: nothing -> list<record> {
  let pins = (action-pins $root)

  # Commit-SHA pins would match no rows, and silence here is indistinguishable
  # from every action being current.
  if ($pins | is-empty) {
    return [{pin: "github actions", pinned: "", upstream: "", status: "UNKNOWN"}]
  }

  $pins | each {|pin|
    let repo = ($pin | split row "@" | first)
    let current = ($pin | split row "@" | last)
    # Actions are pinned to a major tag, so compare only the major component.
    let upstream = (gh-latest-release $repo | split row "." | first)
    {pin: $repo, pinned: $current, upstream: $upstream}
  }
}

def check-cloudflare [root: string]: nothing -> list<record> {
  let file = ([$root $CF_IPS_NIX] | path join)
  let last_updated = (
    open --raw $file | parse --regex 'Last updated: (?<v>\S+)' | get v.0? | default ""
  )
  let pinned = (
    open --raw $file
    | parse --regex '"(?<v>[0-9a-f.:]+/[0-9]+)'
    | get v
    | sort
  )
  let v4 = (query { http get --raw $CF_IPS_V4_URL })
  let v6 = (query { http get --raw $CF_IPS_V6_URL })

  # Either list empty means an incomplete comparison, which would otherwise
  # surface as drift against the half we did fetch.
  if ($pinned | is-empty) or ($v4 | is-empty) or ($v6 | is-empty) {
    return [{pin: "cloudflare-ips", pinned: $last_updated, upstream: "", status: "UNKNOWN"}]
  }

  let upstream = ([$v4 $v6] | str join "\n" | lines | where {|l| $l != "" } | sort)
  if $pinned == $upstream {
    [{pin: "cloudflare-ips", pinned: $last_updated, upstream: "same ranges", status: "ok"}]
  } else {
    [{pin: "cloudflare-ips", pinned: $last_updated, upstream: "ranges differ", status: "STALE"}]
  }
}

# ------------------------------------------------------------------------------
# Reporting
# ------------------------------------------------------------------------------

# A declared status wins, since `renovate` rows compare equal and would
# otherwise be reported as current pins rather than as delegated ones.
def classify []: list<record> -> list<record> {
  each {|row|
    let pinned = ($row.pinned | default "")
    let upstream = ($row.upstream | default "")
    let status = if ($row.status? | is-not-empty) {
      $row.status
    } else if ($pinned | is-empty) or ($upstream | is-empty) {
      "UNKNOWN"
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
  print "Manual pins tracked by this script:\n"
  [
    $"plugin marketplaces   ($PLUGINS_NIX)"
    "custom packages       packages/**/default.nix"
    "container images      modules/nixos/{umami,fuclaude,clove}/default.nix"
    "runtime installs      modules/nixos/piclist/server, shared/notify.nix"
    "github actions        .github/workflows, .github/actions"
    $"upstream data         ($CF_IPS_NIX)"
  ]
  | each {|line| print $"  ($line)" }
  | ignore
  print "\nRenovate covers the 13 flake.lock inputs separately."
}

def cmd-check [] {
  if (which gh | is-empty) { die 'gh not found. Run inside "nix develop" or install it.' }
  if (which jq | is-empty) { die 'jq not found. Run inside "nix develop" or install it.' }
  if ((^gh auth status | complete).exit_code != 0) {
    die 'gh is not authenticated. Run "gh auth login".'
  }

  let root = (repo-root)

  let groups = [
    ["Claude Code plugin marketplaces (rev + hash)" {|| check-plugins $root }]
    ["Custom packages (packages/)" {|| check-packages $root }]
    ["Container images (oci-containers image options)" {|| check-containers $root }]
    ["Runtime-installed packages" {|| check-runtime $root }]
    ["GitHub Actions (Renovate github-actions manager is disabled)" {|| check-actions $root }]
    ["Drifting upstream data" {|| check-cloudflare $root }]
  ]

  let all = $groups | each {|group|
    let rows = (do $group.1 | classify)
    section $group.0 $rows
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
    "-h" | "--help" => { print "Usage: check-pins.nu [check|list]" }
    _ => { die $"unknown subcommand: ($subcommand)" }
  }
}
