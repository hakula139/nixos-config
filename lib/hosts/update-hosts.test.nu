#!/usr/bin/env nu

# ==================================================================================================
# Managed Hosts Updater Tests
# ==================================================================================================

use std/assert
use std-rfc/str
use test-runner.testlib.nu [run-script]
use ./update-hosts.nu [rewrite-hosts]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "update-hosts.nu")

def apply-update [hosts_file: path, owner: string, entries: list<string>]: nothing -> record {
  let config_file = (mktemp)
  {
    hostsFile: $hosts_file
    owner: $owner
    entries: $entries
  }
  | to json
  | save --force $config_file

  run-script $SCRIPT --config $config_file
}

def "test owner transitions preserve unrelated and other-owner entries and are idempotent" [] {
  let unrelated = (
    "
    # Local hosts
    127.0.0.1 localhost
    ::1 localhost

    192.0.2.1 unrelated.example.test # managed elsewhere
    192.0.2.2 similar.example.test # nixos-config-other: tunnel
    192.0.2.3 prefix.example.test # nixos-config: tunnel-extra

    "
    | str dedent
  )
  let other_owner = "0.0.0.0 ingest.t3.codes # nixos-config: telemetry\n"
  let old_tunnel = "127.0.0.1 old-gateway.example.test # nixos-config: tunnel\n"
  let new_tunnel = "127.0.0.1 new-gateway.example.test # nixos-config: tunnel\n"
  let mixed_lines = "192.0.2.1 unrelated.example.test\r\n"
  let unterminated = "192.0.2.2 final.example.test"

  let cases = [
    {
      name: "replace_in_place_before_other_owner"
      initial: ($unrelated + $old_tunnel + $other_owner)
      owner: "tunnel"
      entries: ["127.0.0.1 new-gateway.example.test"]
      expected: ($unrelated + $new_tunnel + $other_owner)
    }
    {
      name: "disable_preserves_other_owner"
      initial: ($unrelated + $old_tunnel + $other_owner)
      owner: "tunnel"
      entries: []
      expected: ($unrelated + $other_owner)
    }
    {
      name: "enable_appends_after_other_owner"
      initial: ($unrelated + $other_owner)
      owner: "tunnel"
      entries: ["127.0.0.1 new-gateway.example.test"]
      expected: ($unrelated + $other_owner + $new_tunnel)
    }
    {
      name: "multiple_entries_for_owner"
      initial: $unrelated
      owner: "telemetry"
      entries: [
        "0.0.0.0 ingest.t3.codes"
        ":: ingest.t3.codes"
      ]
      expected: (
        $unrelated
        + "0.0.0.0 ingest.t3.codes # nixos-config: telemetry\n"
        + ":: ingest.t3.codes # nixos-config: telemetry\n"
      )
    }
    {
      name: "remove_all"
      initial: ($old_tunnel | str trim --right)
      owner: "tunnel"
      entries: []
      expected: ""
    }
    {
      name: "empty_file"
      initial: ""
      owner: "tunnel"
      entries: ["127.0.0.1 new-gateway.example.test"]
      expected: $new_tunnel
    }
    {
      name: "line_endings_in_place"
      initial: ($mixed_lines + $old_tunnel + $unterminated)
      owner: "tunnel"
      entries: ["127.0.0.1 new-gateway.example.test"]
      expected: ($mixed_lines + $new_tunnel + $unterminated)
    }
    {
      name: "line_endings_append"
      initial: ($mixed_lines + $unterminated)
      owner: "tunnel"
      entries: ["127.0.0.1 new-gateway.example.test"]
      expected: ($mixed_lines + $unterminated + (char nl) + $new_tunnel)
    }
    {
      name: "disabled_line_endings"
      initial: ($mixed_lines + $old_tunnel + $unterminated)
      owner: "tunnel"
      entries: []
      expected: ($mixed_lines + $unterminated)
    }
  ]

  for case in $cases {
    let output = (rewrite-hosts $case.initial $case.owner $case.entries)
    assert equal $output $case.expected $case.name

    let repeated = (rewrite-hosts $output $case.owner $case.entries)
    assert equal $repeated $case.expected $"($case.name) repeated"
  }
}

def "test multiple owners do not reorder each other across repeated runs" [] {
  let telemetry = ["0.0.0.0 ingest.t3.codes" ":: ingest.t3.codes"]
  let tunnel = ["127.0.0.1 gw.example.test"]

  let after_telemetry = (rewrite-hosts "127.0.0.1 localhost\n" "telemetry" $telemetry)
  let after_tunnel = (rewrite-hosts $after_telemetry "tunnel" $tunnel)

  assert equal (rewrite-hosts $after_tunnel "telemetry" $telemetry) $after_tunnel
  assert equal (rewrite-hosts $after_tunnel "tunnel" $tunnel) $after_tunnel
}

def "test in-place update writes atomically and is idempotent" [] {
  let dir = (mktemp --directory)
  let hosts_file = ($dir | path join "hosts")
  "127.0.0.1 localhost\n" | save --force $hosts_file

  let telemetry = ["0.0.0.0 ingest.t3.codes" ":: ingest.t3.codes"]
  let tunnel = ["127.0.0.1 gw.example.test"]

  let run1 = (apply-update $hosts_file "telemetry" $telemetry)
  assert equal $run1.exit_code 0 $run1.stderr

  let run2 = (apply-update $hosts_file "tunnel" $tunnel)
  assert equal $run2.exit_code 0 $run2.stderr

  let expected = (
    "
    127.0.0.1 localhost
    0.0.0.0 ingest.t3.codes # nixos-config: telemetry
    :: ingest.t3.codes # nixos-config: telemetry
    127.0.0.1 gw.example.test # nixos-config: tunnel

    "
    | str dedent
  )
  assert equal (open --raw $hosts_file) $expected
  assert equal (ls -l $hosts_file | get 0.mode) "rw-r--r--"

  let run3 = (apply-update $hosts_file "telemetry" $telemetry)
  assert equal $run3.exit_code 0 $run3.stderr
  assert equal (open --raw $hosts_file) $expected
  assert equal (ls --all $dir | get name | path basename) ["hosts"]
}

def "test an unreadable hosts file fails without creating it" [] {
  let hosts_file = (mktemp --directory | path join "missing")

  let run = (apply-update $hosts_file "tunnel" ["127.0.0.1 new-gateway.example.test"])

  assert not equal $run.exit_code 0
  assert not ($hosts_file | path exists)
}
