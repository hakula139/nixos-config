#!/usr/bin/env nu

# ==================================================================================================
# BetterDisplay License Activation
# ==================================================================================================

# Check activation without printing the licensing output.
def is-activated [app: path]: nothing -> bool {
  let status = (^$app manageLicense -status | complete)
  if $status.exit_code != 0 {
    error make {msg: "Could not read BetterDisplay activation status"}
  }

  # Activation status emitted by BetterDisplay's licensing CLI.
  $status.stdout | lines | parse -r '^Activation Status:\s*Activated\s*$' | is-not-empty
}

# Activate BetterDisplay from a SOPS license. Missing prerequisites are skipped until the launch
# agent runs again.
def main [
  --app: path # Wrapper-supplied BetterDisplay executable
  --email-file: path # Wrapper-supplied file containing the purchase email
  --key-file: path # Wrapper-supplied file containing the license key
] {
  if not ($app | path exists) or not ($email_file | path exists) or not ($key_file | path exists) {
    return
  }

  if (is-activated $app) {
    return
  }

  let email = open --raw $email_file | str trim
  let key = open --raw $key_file | str trim
  let result = (
    ^$app manageLicense
      -activate
      $"-email=($email)"
      $"-key=($key)"
    | complete
  )
  if $result.exit_code != 0 or not (is-activated $app) {
    error make {msg: "BetterDisplay license activation failed"}
  }
}
