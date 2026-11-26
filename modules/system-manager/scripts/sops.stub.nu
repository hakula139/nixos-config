#!/usr/bin/env nu

# ==================================================================================================
# SOPS Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  let key_file = ($env.SOPS_AGE_KEY_FILE? | default "")
  let key_mode = if ($key_file | is-not-empty) and ($key_file | path exists) {
    ^stat -c "%a" $key_file | str trim
  } else {
    ""
  }

  {
    command: "sops"
    args: $args
    key_file: $key_file
    key_mode: $key_mode
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  if ($env.STUB_SOPS_FAIL? | default "") == "1" {
    print -e "stub sops failure"
    exit 1
  }

  let out_idx = ($args | enumerate | where item == "--output" | first | get index) + 1
  let out_path = ($args | get $out_idx)
  $"decrypted:($args | last)" | save --force $out_path
}
