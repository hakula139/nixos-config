#!/usr/bin/env nu

# ==================================================================================================
# Pinned Version Drift Check
# ==================================================================================================
# Compare the registered manual pins against their upstream values and report which ones have
# drifted. Renovate-managed pins (flake.lock inputs and GitHub Actions) are out of scope. See
# ../SKILL.md for why.
#
# Run with --help for usage.
# ==================================================================================================

const PLUGINS_NIX = "home/modules/llm-assistants/claude-code/plugins.nix"
const CF_IPS_NIX = "modules/nixos/cloudflare/ips.nix"

# The overlay applies the custom packages to every host, so one host's package set covers each
# override and the channel it overrides.
const EVAL_PKGS = "nixosConfigurations.us-1.pkgs"

const CF_IPS_V4_URL = "https://www.cloudflare.com/ips-v4"
const CF_IPS_V6_URL = "https://www.cloudflare.com/ips-v6"

# Commit prefix length used by the plugin bundle.
const REV_ABBREV = 12

# --------------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------------

# A missing prerequisite leaves the run incomplete, so it shares exit 2 with a failed query.
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
def query [pin: string, closure: closure]: nothing -> string {
  try { do $closure | into string | str trim } catch {|err|
    print -e $"  ($pin): ($err.msg)"
    ""
  }
}

def abbrev [rev: string]: nothing -> string {
  if ($rev | str length) <= $REV_ABBREV { $rev } else { $rev | str substring 0..<$REV_ABBREV }
}

# Evaluate a field of an attribute through the flake at `root`, capturing stderr so evaluation
# warnings stay off the terminal. A failure prints the first `error:` line, falling back to the
# last line, and returns "".
def flake-attr [root: string, attr: string, field: string, --json]: nothing -> string {
  let mode = if $json { "--json" } else { "--raw" }
  let result = (^nix eval $mode $"($root)#($attr).($field)" | complete)
  if $result.exit_code != 0 {
    let lines = ($result.stderr | lines | where {|line| $line | is-not-empty })
    let error_line = ($lines | where {|line| $line | str starts-with "error:" } | first)
    let detail = ($error_line | default ($lines | last | default ""))

    print -e $"  cannot evaluate ($attr).($field): ($detail)"
    ""
  } else {
    $result.stdout | str trim
  }
}

# Whether the left version is at or above the right one. The release core compares first, and a
# final release ranks above the same core's pre-release.
def version-at-least [left: string, right: string]: nothing -> bool {
  let left_core = ($left | split row "-" | first | str replace -r '^v' '')
  let right_core = ($right | split row "-" | first | str replace -r '^v' '')
  let left_suffix = ($left | split row "-" | skip 1 | str join "-")
  let right_suffix = ($right | split row "-" | skip 1 | str join "-")

  if $left_core != $right_core {
    ([$left_core $right_core] | sort --natural | last) == $left_core
  } else if ($left_suffix | is-empty) != ($right_suffix | is-empty) {
    $left_suffix | is-empty
  } else {
    ([$left_suffix $right_suffix] | sort --natural | last) == $left_suffix
  }
}

# Whether the left version is below the right one.
def version-older [left: string, right: string]: nothing -> bool {
  not (version-at-least $left $right)
}

# --------------------------------------------------------------------------------------------------
# Upstream queries
# --------------------------------------------------------------------------------------------------

def gh-api [path: string, jq: string]: nothing -> string {
  ^gh api --hostname github.com $path --jq $jq | str trim
}

def gh-latest-release [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/releases/latest" ".tag_name"
}

# `releases/latest` skips pre-releases, which may be all an upstream has published.
def gh-newest-release [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/releases?per_page=1" ".[0].tag_name"
}

def gh-newest-tag [repo: string]: nothing -> string {
  ^gh api --hostname github.com $"repos/($repo)/tags" --paginate --jq ".[].name"
  | lines
  | where {|tag| $tag =~ '^v?[0-9]+(\.[0-9]+)*$' }
  | reduce --fold "" {|tag, newest|
    if ($newest | is-empty) or (version-at-least $tag $newest) { $tag } else { $newest }
  }
}

def gh-newest-tag-head [repo: string]: nothing -> string {
  let tag = (gh-newest-tag $repo)
  gh-api $"repos/($repo)/commits/($tag)" ".sha"
}

# Upstream's newest release may ship no binaries, which is not a bumpable target.
def gh-latest-release-with-asset [repo: string, asset: string]: nothing -> string {
  gh-api $"repos/($repo)/releases?per_page=100" "."
  | from json
  | where {|release| $release.assets | any {|entry| $entry.name == $asset } }
  | first
  | get tag_name
}

def gh-default-head [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/commits?per_page=1" ".[0].sha"
}

# --------------------------------------------------------------------------------------------------
# Pin extraction
# --------------------------------------------------------------------------------------------------

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
  | get rev.0
}

def nix-attr [root: string, file: string, regex: string]: nothing -> string {
  open --raw ([$root $file] | path join) | parse --regex $regex | get v.0
}

def nix-version [root: string, file: string]: nothing -> string {
  nix-attr $root $file '(?m)^\s*version = "(?<v>[^"]+)"'
}

def nix-version-v [root: string, file: string]: nothing -> string {
  $"v(nix-version $root $file)"
}

def image-tag [root: string, file: string]: nothing -> string {
  open --raw ([$root $file] | path join)
  | lines
  | skip until {|l| $l =~ 'image = lib.mkOption' }
  | take until {|l| $l =~ '^\s*};\s*$' }
  | str join "\n"
  | parse --regex 'default = "[^"]*:(?<v>[^"]+)"'
  | get v.0
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

# --------------------------------------------------------------------------------------------------
# Cloudflare comparison
# --------------------------------------------------------------------------------------------------

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
    | each {|url| http get --raw $url | str trim }
  )

  # An empty half would otherwise surface as drift against the half we did fetch.
  if ($pinned | is-empty) or ($fetched | any {|r| $r | is-empty }) {
    error make {msg: "Cloudflare IP ranges are incomplete"}
  }

  if $pinned == ($fetched | str join "\n" | lines --skip-empty | sort) {
    "same ranges"
  } else {
    "ranges differ"
  }
}

# --------------------------------------------------------------------------------------------------
# Pin registry
# --------------------------------------------------------------------------------------------------

# One row per override package, pairing its evaluated version and derivation with the latest
# upstream release and the version `nixpkgs-unstable` ships.
def override-rows [root: string, overrides: list<record>]: nothing -> list<record> {
  $overrides | each {|override|
    let name = $override.name
    let file = $"packages/($name)/default.nix"
    let local_attr = $"($EVAL_PKGS).($name)"
    let unstable_attr = $"($EVAL_PKGS).unstable.($name)"

    {
      pin: $name
      local: {|| flake-attr $root $local_attr "version" }
      upstream: {|| gh-latest-release $override.repo | str replace -r '^v' '' }
      status: {|pinned, latest|
        if not ([$root $file] | path join | path exists) {
          print -e $"  ($name): ($file) is missing"
          "UNKNOWN"
        } else {
          let unstable = (flake-attr $root $unstable_attr "version")
          let pinned_in_file = (try { nix-version $root $file } catch { "" })

          if ($unstable | is-empty) {
            "UNKNOWN"
          } else if ($pinned_in_file | is-not-empty) {
            if (version-at-least $unstable $latest) and (version-at-least $unstable $pinned) {
              "version pin superseded"
            } else if (version-older $pinned $latest) {
              "STALE"
            } else {
              "ok"
            }
          } else {
            let local_drv = (flake-attr $root $local_attr "drvPath")
            let unstable_drv = (flake-attr $root $unstable_attr "drvPath")
            let local_platforms = (flake-attr $root $local_attr "meta.platforms" --json)
            let unstable_platforms = (flake-attr $root $unstable_attr "meta.platforms" --json)
            let evaluated = [$local_drv $unstable_drv $local_platforms $unstable_platforms]

            if (version-older $unstable $latest) {
              "STALE"
            } else if ($evaluated | any {|value| $value | is-empty }) {
              "UNKNOWN"
            } else if ($local_drv == $unstable_drv) and ($local_platforms == $unstable_platforms) {
              "override redundant"
            } else {
              "ok (tracks nixpkgs)"
            }
          }
        }
      }
    }
  }
}

# Renovate's github-actions manager updates these refs, so the row delegates.
def action-pin [pin: string]: nothing -> record {
  {
    pin: ($pin | split row "@" | first)
    local: {|| $pin | split row "@" | last }
    delegated: "renovate"
  }
}

# Each row pairs a pin name with closures that read the local value and the upstream value. Both
# stay lazy so `list` can print the registry without touching the network.
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
        {
          pin: "oxide-code"
          local: {|| nix-attr $root "flake.nix" 'github:hakula139/oxide-code/(?<v>[^"]+)' }
          upstream: {|| gh-newest-release "hakula139/oxide-code" }
        }
      ]
    }
    {
      title: "Claude Code plugin marketplaces (rev + hash)"
      pins: [
        {
          pin: "claude-plugins-official"
          local: {|| abbrev (plugin-rev $root "claude-plugins-official") }
          upstream: {|| abbrev (gh-default-head "anthropics/claude-plugins-official") }
        }
        {
          pin: "workmux"
          local: {|| "flake.lock" }
          delegated: "renovate"
        }
      ]
    }
    {
      title: "OMP extensions (rev + hash)"
      pins: [
        {
          pin: "omp-telegram"
          local: {||
            let file = "home/modules/llm-assistants/omp/extensions.nix"
            abbrev (nix-attr $root $file 'rev = "(?<v>[0-9a-f]+)"')
          }
          # Upstream publishes tags without GitHub release objects.
          upstream: {|| abbrev (gh-newest-tag-head "TerrifiedBug/omp-telegram") }
        }
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
          pin: "thaw"
          local: {|| nix-version $root "packages/thaw/default.nix" }
          upstream: {|| gh-newest-release "thaw-app/Thaw" }
        }
        {
          pin: "zsh-hist"
          local: {||
            let file = "packages/zsh-hist/default.nix"
            abbrev (nix-attr $root $file 'rev = "(?<v>[0-9a-f]+)"')
          }
          upstream: {|| abbrev (gh-default-head "marlonrichert/zsh-hist") }
        }
      ]
    }
    {
      title: "Repo overrides of nixpkgs packages"
      pins: (
        override-rows $root [
          {name: "netdata", repo: "netdata/netdata"}
          {name: "peertube", repo: "Chocobozzz/PeerTube"}
          {name: "wakatime-cli", repo: "wakatime/wakatime-cli"}
        ]
      )
    }
    {
      title: "Windows notification helper"
      pins: [
        {
          pin: "toasty"
          local: {||
            let file = "home/modules/llm-assistants/shared/notify/default.nix"
            nix-attr $root $file 'download/(?<v>v?[0-9.]+)'
          }
          upstream: {|| gh-latest-release-with-asset "shanselman/toasty" "toasty-x64.exe" }
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
      ]
    }
    {
      title: "GitHub Actions"
      pins: (try { action-pins $root | each {|pin| action-pin $pin } } catch { [] })
    }
    {
      title: "Drifting upstream data"
      pins: [
        {
          pin: "cloudflare-ips"
          local: {|| nix-attr $root $CF_IPS_NIX 'Last updated: (?<v>\S+)' }
          upstream: {|| cloudflare-drift $root }
          # The pinned column is a date and the upstream one a verdict, so they are not comparable.
          status: {|_pinned, upstream| match $upstream { "same ranges" => "ok", _ => "STALE" } }
        }
      ]
    }
  ]
}

# --------------------------------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------------------------------

def resolve []: list<record> -> list<record> {
  par-each --keep-order {|row|
    if ($row.delegated? | is-not-empty) {
      let pinned = (query $row.pin $row.local)
      return {pin: $row.pin, pinned: $pinned, upstream: "renovate", status: $row.delegated}
    }

    let pinned = (query $row.pin $row.local)
    let upstream = (query $row.pin $row.upstream)
    let status = if ($pinned | is-empty) or ($upstream | is-empty) {
      "UNKNOWN"
    } else if ($row.status? | is-not-empty) {
      do $row.status $pinned $upstream
    } else if $pinned == $upstream {
      "ok"
    } else {
      "STALE"
    }

    {
      pin: $row.pin
      pinned: ($pinned | default --empty "?")
      upstream: ($upstream | default --empty "?")
      status: $status
    }
  }
}

def resolve-group [group: record]: nothing -> record {
  let rows = if ($group.pins | is-empty) {
    # An empty group would print as a clean sweep, indistinguishable from every pin being current.
    print -e $"  ($group.title): no pins matched"
    [{pin: $group.title, pinned: "?", upstream: "?", status: "UNKNOWN"}]
  } else {
    $group.pins | resolve
  }
  {title: $group.title, rows: $rows}
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Compare registered manual pins with upstream versions.
def "main check" [] {
  if (which gh | is-empty) {
    die "gh not found. Install GitHub CLI and authenticate to github.com."
  }
  if ((^gh auth status --hostname github.com | complete).exit_code != 0) {
    die "GitHub authentication check failed. Check credentials and network access."
  }

  # Resolution finishes before anything prints, since `par-each` threads would otherwise interleave
  # their sections.
  let groups = (
    registry (repo-root)
    | par-each --keep-order {|group| resolve-group $group }
  )

  for group in $groups {
    print $"\n($group.title)"
    print ($group.rows | table)
  }
  let rows = ($groups | get rows | flatten)

  let stale = (
    $rows
    | where {|row| $row.status in ["STALE" "version pin superseded" "override redundant"] }
    | length
  )
  let unknown = ($rows | where status == "UNKNOWN" | length)

  print $"\n($stale) stale, ($unknown) unknown."
  if $unknown > 0 {
    print "UNKNOWN means a lookup failed. Rerun, and fix the printed cause if it persists."
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
  print "\nRenovate owns the flake.lock inputs and the GitHub Actions refs."
}

# Check registered manual pins for upstream drift by default.
def main [] {
  main check
}
