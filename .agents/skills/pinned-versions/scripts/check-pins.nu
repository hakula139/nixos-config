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

use pin-check

# The overlay applies the custom packages to every host, so one host's package set covers each
# override and the channel it overrides.
const EVAL_PKGS = "nixosConfigurations.us-1.pkgs"

const REV_ABBREV = 12

# --------------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------------

def abbrev [rev: string]: nothing -> string {
  if ($rev | str length) <= $REV_ABBREV {
    $rev
  } else {
    $rev | str substring 0..<$REV_ABBREV
  }
}

# Evaluate a field of an attribute through the flake at `root`, capturing stderr so evaluation
# warnings stay off the terminal. A failure prints the first `error:` line, falling back to the
# last line, and returns null.
def flake-attr [
  root: string
  attr: string
  field: string
  --json
]: nothing -> oneof<string, nothing> {
  let mode = if $json { "--json" } else { "--raw" }
  let result = (^nix eval $mode $"($root)#($attr).($field)" | complete)
  if $result.exit_code != 0 {
    let lines = ($result.stderr | lines | where {|line| $line | is-not-empty })
    let error_line = ($lines | where {|line| $line | str starts-with "error:" } | first)
    let detail = ($error_line | default ($lines | last | default ""))

    print -e $"cannot evaluate ($attr).($field): ($detail)"
    null
  } else {
    $result.stdout | str trim
  }
}

# --------------------------------------------------------------------------------------------------
# Pin extraction
# --------------------------------------------------------------------------------------------------

def image-tag [root: string, file: string]: nothing -> string {
  open --raw ($root | path join $file)
  | lines
  | skip until {|l| $l =~ "image = lib.mkOption" }
  | take until {|l| $l =~ '^\s*};\s*$' }
  | str join "\n"
  | parse --regex 'default = "[^"]*:(?<v>[^"]+)"'
  | get v.0
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
      local: {|| flake-attr $root $local_attr version }
      upstream: {|| pin-check gh-latest-release $override.repo | str replace -r "^v" "" }
      classify: {|pinned, latest|
        if not ($root | path join $file | path exists) {
          print -e $"($name): ($file) is missing"
          {
            status: "UNKNOWN"
            outcome: "unknown"
          }
        } else {
          let unstable = (flake-attr $root $unstable_attr version)
          let pinned_in_file = try {
            pin-check nix-version $root $file
          } catch {
            ""
          }

          if ($unstable | is-empty) {
            {
              status: "UNKNOWN"
              outcome: "unknown"
            }
          } else if ($pinned_in_file | is-not-empty) {
            if (
              (pin-check version-at-least $unstable $latest)
              and (pin-check version-at-least $unstable $pinned)
            ) {
              {
                status: "version pin superseded"
                outcome: "stale"
              }
            } else if (pin-check version-older $pinned $latest) {
              {
                status: "STALE"
                outcome: "stale"
              }
            } else {
              {
                status: "ok"
                outcome: "current"
              }
            }
          } else {
            let local_drv = (flake-attr $root $local_attr drvPath)
            let unstable_drv = (flake-attr $root $unstable_attr drvPath)
            let local_platforms = (flake-attr $root $local_attr meta.platforms --json)
            let unstable_platforms = (flake-attr $root $unstable_attr meta.platforms --json)
            let evaluated = [$local_drv $unstable_drv $local_platforms $unstable_platforms]

            if (pin-check version-older $unstable $latest) {
              {
                status: "STALE"
                outcome: "stale"
              }
            } else if ($evaluated | any {|value| $value | is-empty }) {
              {
                status: "UNKNOWN"
                outcome: "unknown"
              }
            } else if ($local_drv == $unstable_drv) and ($local_platforms == $unstable_platforms) {
              {
                status: "override redundant"
                outcome: "stale"
              }
            } else {
              {
                status: "ok (tracks nixpkgs)"
                outcome: "current"
              }
            }
          }
        }
      }
    }
  }
}

# Each row pairs a pin name with closures that read the local value and the upstream value. Both
# stay lazy so `list` can print the registry without touching the network.
def registry []: nothing -> list<record> {
  let root = (pin-check repo-root "nixos-config")

  [
    {
      title: "Nix-built overlay packages"
      pins: [
        {
          pin: "cloudreve"
          local: {|| pin-check nix-version $root "packages/cloudreve/default.nix" }
          upstream: {|| pin-check gh-latest-release "cloudreve/cloudreve" }
        }
        {
          pin: "thaw"
          local: {|| pin-check nix-version $root "packages/thaw/default.nix" }
          upstream: {|| pin-check gh-newest-release "thaw-app/Thaw" }
        }
        {
          pin: "zsh-hist"
          local: {||
            let file = "packages/zsh-hist/default.nix"
            abbrev (pin-check nix-attr $root $file 'rev = "(?<v>[0-9a-f]+)"')
          }
          upstream: {|| abbrev (pin-check gh-default-head "marlonrichert/zsh-hist") }
        }
      ]
    }
    {
      title: "Repo overrides of nixpkgs packages"
      pins: (
        override-rows $root [
          [name repo];
          ["peertube" "Chocobozzz/PeerTube"]
        ]
      )
    }
    {
      title: "Container images (oci-containers image options)"
      pins: [
        {
          pin: "umami"
          local: {|| image-tag $root "modules/nixos/umami/default.nix" }
          upstream: {||
            pin-check gh-latest-release "umami-software/umami" | str replace -r "^v" ""
          }
        }
      ]
    }
    {
      title: "GitHub Actions"
      pins: (try {
        pin-check action-pins $root | each {|pin| pin-check action-pin $pin }
      } catch {
        []
      })
    }
  ]
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Compare registered manual pins with upstream versions.
def "main check" [] {
  pin-check check {|| registry }
}

# List the registered pins without querying upstream.
def "main list" [] {
  let footer = "Renovate owns the flake.lock inputs and the GitHub Actions refs."
  pin-check list {|| registry } --footer $footer
}

# Check registered manual pins for upstream drift by default.
def main [] {
  main check
}
