#!/usr/bin/env nu

# ==================================================================================================
# System Manager SOPS Secret Installer Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "install-secrets.nu")

def run-installer [
  cfg: record
  --sops-fail
]: nothing -> record {
  let log = (mktemp)
  let config_file = (mktemp --suffix ".json")
  $cfg | to json | save --force $config_file

  let run = with-env {
    PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
    STUB_LOG: $log
    STUB_SOPS_FAIL: (if $sops_fail { "1" } else { "0" })
  } {
    run-script $SCRIPT --config $config_file
  }

  let calls = if ($log | path exists) and ((open --raw $log | str trim) | is-not-empty) {
    open --raw $log | from json --objects
  } else {
    []
  }

  {
    run: $run
    calls: $calls
  }
}

def "test installs YAML key and whole-file secrets with modes and ownership" [] {
  let root = (mktemp --directory)
  let identity = ($root | path join "id_ed25519")
  "stub-private-key" | save $identity

  let secrets_dir = ($root | path join "secrets")
  let manifest = ($root | path join "state/managed-secrets")
  let yaml_target = ($secrets_dir | path join "app/token")
  let ini_target = ($secrets_dir | path join "wakatime.ini")

  let result = (
    run-installer {
      secretsDir: $secrets_dir
      managedPathsFile: $manifest
      identityPaths: [
        ($root | path join "missing-key")
        $identity
      ]
      secrets: [
        {
          name: "app/token"
          sopsFile: "/store/common.yaml"
          format: "yaml"
          key: "app/nested/token"
          owner: "hakula"
          group: "users"
          mode: "0400"
          path: $yaml_target
        }
        {
          name: "wakatime/config"
          sopsFile: "/store/wakatime.ini"
          format: "ini"
          key: ""
          owner: "hakula"
          group: "hakula"
          mode: "0440"
          path: $ini_target
        }
      ]
    }
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert str contains $result.run.stderr "warning: sops SSH identity not readable"

  assert equal (^stat -c "%a" $secrets_dir | str trim) "751"
  assert equal (^stat -c "%a" ($secrets_dir | path join "app") | str trim) "700"
  assert equal (^stat -c "%a" $yaml_target | str trim) "400"
  assert equal (^stat -c "%a" $ini_target | str trim) "440"
  assert equal (open --raw $yaml_target) "decrypted:/store/common.yaml"
  assert equal (open --raw $ini_target) "decrypted:/store/wakatime.ini"

  let sops_calls = ($result.calls | where command == "sops")
  assert equal ($sops_calls | length) 2
  assert equal $sops_calls.0.args [
    "decrypt"
    "--input-type"
    "yaml"
    "--extract"
    '["app"]["nested"]["token"]'
    "--output"
    $"($yaml_target).tmp"
    "/store/common.yaml"
  ]
  assert equal $sops_calls.0.key_mode "600"
  assert not ($sops_calls.0.key_file | path exists)
  assert equal $sops_calls.1.args [
    "decrypt"
    "--input-type"
    "ini"
    "--output-type"
    "ini"
    "--output"
    $"($ini_target).tmp"
    "/store/wakatime.ini"
  ]

  let chown_calls = ($result.calls | where command == "chown" | get args)
  assert equal $chown_calls [
    ["hakula:users" ($secrets_dir | path join "app")]
    ["hakula:users" $"($yaml_target).tmp"]
    ["hakula:hakula" $"($ini_target).tmp"]
  ]

  assert equal (open --raw $manifest | lines) [$yaml_target $ini_target]
}

def "test prunes stale paths recorded in the previous manifest" [] {
  let root = (mktemp --directory)
  let identity = ($root | path join "id_ed25519")
  "stub-private-key" | save $identity

  let secrets_dir = ($root | path join "secrets")
  let manifest = ($root | path join "state/managed-secrets")
  let keep_target = ($secrets_dir | path join "keep")
  let stale_target = ($secrets_dir | path join "stale")

  mkdir $secrets_dir ($manifest | path dirname)
  "old" | save $stale_target
  $"($keep_target)\n($stale_target)\n" | save $manifest

  let result = (
    run-installer {
      secretsDir: $secrets_dir
      managedPathsFile: $manifest
      identityPaths: [$identity]
      secrets: [
        {
          name: "keep"
          sopsFile: "/store/common.yaml"
          format: "yaml"
          key: "keep"
          owner: "root"
          group: "root"
          mode: "0400"
          path: $keep_target
        }
      ]
    }
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert ($keep_target | path exists)
  assert not ($stale_target | path exists)
  assert equal (open --raw $manifest | lines) [$keep_target]
}

def "test cleans up temporary age key file when sops fails" [] {
  let root = (mktemp --directory)
  let identity = ($root | path join "id_ed25519")
  "stub-private-key" | save $identity

  let result = (
    run-installer --sops-fail {
      secretsDir: ($root | path join "secrets")
      managedPathsFile: ($root | path join "state/managed-secrets")
      identityPaths: [$identity]
      secrets: [
        {
          name: "fail"
          sopsFile: "/store/common.yaml"
          format: "yaml"
          key: "fail"
          owner: "root"
          group: "root"
          mode: "0400"
          path: ($root | path join "secrets/fail")
        }
      ]
    }
  )

  assert not ($result.run.exit_code == 0)
  let sops_call = ($result.calls | where command == "sops" | first)
  assert not ($sops_call.key_file | path exists)
}

def "test fails when no readable SSH identities exist" [] {
  let root = (mktemp --directory)
  let result = (
    run-installer {
      secretsDir: ($root | path join "secrets")
      managedPathsFile: ($root | path join "state/managed-secrets")
      identityPaths: [($root | path join "nonexistent")]
      secrets: []
    }
  )

  assert not ($result.run.exit_code == 0)
  assert str contains $result.run.stderr "No readable SSH identities found"
}
