#!/usr/bin/env nu

# ==================================================================================================
# Nix GitHub Access Token Activation Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "activate-access-tokens.nu")

def "test activation writes trimmed access token with 0600 permissions" [] {
  let dir = (mktemp --directory | path expand --strict)
  let token_file = ($dir | path join "pat")
  let output_file = ($dir | path join "nix/access-tokens.conf")
  "  ghp_example_token_12345 \n" | save --raw $token_file

  let run = (
    run-script $SCRIPT
      --token-file $token_file
      --output-file $output_file
  )
  assert equal $run.exit_code 0 $run.stderr

  let actual = (open --raw $output_file | into string)
  assert equal $actual "extra-access-tokens = github.com=ghp_example_token_12345\n"
  assert equal (ls --long $output_file | get 0.mode) "rw-------"
}

def "test activation removes existing output when token file is missing or blank" [] {
  for case in [
    [name content];
    ["missing-pat" null]
    ["blank-pat" "  \n\t\n"]
  ] {
    let dir = (mktemp --directory | path expand --strict)
    let token_file = ($dir | path join $case.name)
    let output_file = ($dir | path join "access-tokens.conf")
    if $case.content != null {
      $case.content | save --raw $token_file
    }
    "extra-access-tokens = github.com=stale\n" | save --raw $output_file

    let run = (
      run-script $SCRIPT
        --token-file $token_file
        --output-file $output_file
    )
    assert equal $run.exit_code 0 $run.stderr

    assert (not ($output_file | path exists)) $case.name
  }
}
