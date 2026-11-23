#!/usr/bin/env nu

# ==================================================================================================
# Nix GitHub Access Token Activation
# ==================================================================================================

use config-file.nu [save-atomic]

# Render Nix's GitHub access token include file from a decrypted secret, or remove it when empty.
def main [
  --token-file: path # Path to the decrypted GitHub personal access token
  --output-file: path # Path to the generated Nix include file
] {
  let token = if ($token_file | path exists) {
    try {
      let raw = (open --raw $token_file | into string)
      $raw | str trim
    } catch {
      ""
    }
  } else {
    ""
  }

  if ($token | is-empty) {
    rm --force $output_file
    return
  }

  mkdir ($output_file | path dirname)
  save-atomic $"extra-access-tokens = github.com=($token)\n" $output_file
  ^chmod 600 $output_file
}
