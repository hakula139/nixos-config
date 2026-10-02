#!/usr/bin/env nu

# ==============================================================================
# BetterDisplay License Activation
# ==============================================================================

# Check activation without printing the licensing output.
def is-activated [app: path]: nothing -> bool {
  let status = (^$app manageLicense -status | complete)
  if $status.exit_code != 0 {
    error make {msg: "Could not read BetterDisplay activation status"}
  }

  # Activation status emitted by BetterDisplay's licensing CLI.
  $status.stdout | lines | parse -r '^Activation Status:\s*Activated\s*$' | is-not-empty
}

# Activate BetterDisplay from an agenix license.
# Missing prerequisites are skipped until the launch agent runs again.
def main [
  license_file: path # JSON file containing the purchase email and license key
  app: path # BetterDisplay executable
] {
  if not ($license_file | path exists) or not ($app | path exists) {
    return
  }

  if (is-activated $app) {
    return
  }

  let license = open --raw $license_file | from json
  let result = (
    ^$app manageLicense -activate
      $"-email=($license.email)"
      $"-key=($license.key)"
    | complete
  )
  if $result.exit_code != 0 or not (is-activated $app) {
    error make {msg: "BetterDisplay license activation failed"}
  }
}
