#!/usr/bin/env nu

# ==================================================================================================
# Tunnel Hosts Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join hosts.nu)

def rewrite [hosts_file: path, hostname: string]: nothing -> string {
  let run = (^$nu.current-exe --no-config-file $SCRIPT $hosts_file $hostname | complete)
  assert equal $run.exit_code 0 $run.stderr

  $run.stdout
}

def "test hostname transitions preserve unrelated entries and are idempotent" [] {
  let unrelated = (
    "
    # Local hosts
    127.0.0.1 localhost
    ::1 localhost

    192.0.2.1 unrelated.example.test # managed elsewhere
    192.0.2.2 similar.example.test # nixos-config-other: corp-tunnel

    "
    | str dedent
  )
  let old_entries = (
    "
    127.0.0.1 old-gateway.example.test # nixos-config: corp-tunnel
    127.0.0.1 legacy-gateway.example.test # nixos-config: earlier-tunnel

    "
    | str dedent
  )
  let new_entry = "127.0.0.1 new-gateway.example.test # nixos-config: corp-tunnel\n"
  let mixed_lines = "192.0.2.1 unrelated.example.test\r\n"
  let unterminated = "192.0.2.2 final.example.test"
  let cases = [
    {
      name: rename
      initial: ($unrelated + $old_entries)
      hostname: new-gateway.example.test
      expected: ($unrelated + $new_entry)
    }
    {
      name: disable
      initial: ($unrelated + $old_entries + $new_entry)
      hostname: ""
      expected: $unrelated
    }
    {
      name: enable
      initial: $unrelated
      hostname: new-gateway.example.test
      expected: ($unrelated + $new_entry)
    }
    {
      name: remove_all
      initial: ($old_entries | str trim --right)
      hostname: ""
      expected: ""
    }
    {name: empty, initial: "", hostname: new-gateway.example.test, expected: $new_entry}
    {
      name: line_endings
      initial: ($mixed_lines + $old_entries + $unterminated)
      hostname: new-gateway.example.test
      expected: ($mixed_lines + $unterminated + (char nl) + $new_entry)
    }
    {
      name: disabled_line_endings
      initial: ($mixed_lines + $old_entries + $unterminated)
      hostname: ""
      expected: ($mixed_lines + $unterminated)
    }
  ]

  for case in $cases {
    let hosts_file = (mktemp)
    $case.initial | save --force $hosts_file

    let output = (rewrite $hosts_file $case.hostname)

    assert equal $output $case.expected $case.name
    assert equal (open --raw $hosts_file | default "") $case.initial $"($case.name) input"

    $output | save --force $hosts_file

    assert equal (rewrite $hosts_file $case.hostname) $case.expected $"($case.name) repeated"
  }
}

def "test an unreadable hosts file does not produce a replacement entry" [] {
  let hosts_file = ((mktemp --directory) | path join missing)

  let run = (
    ^$nu.current-exe --no-config-file $SCRIPT $hosts_file new-gateway.example.test
    | complete
  )

  assert not equal $run.exit_code 0
  assert equal $run.stdout ""
}
