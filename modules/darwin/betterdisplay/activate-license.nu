#!/usr/bin/env nu

# ==============================================================================
# BetterDisplay License Activation
# ==============================================================================
# Run with --help for usage.
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

# Activate BetterDisplay from an agenix license without logging credentials.
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

  # Isolate parsing because JSON diagnostics can include credential contents.
  let parsed = with-env {BETTERDISPLAY_LICENSE_PATH: $license_file} {
    (^$nu.current-exe --no-config-file --commands
      'open --raw $env.BETTERDISPLAY_LICENSE_PATH | from json | select email key | to json'
      | complete)
  }
  if $parsed.exit_code != 0 {
    error make {msg: "Could not read BetterDisplay license credentials"}
  }
  let license = $parsed.stdout | from json
  let result = (^$app manageLicense -activate
    $"-email=($license.email)"
    $"-key=($license.key)"
    | complete)
  if $result.exit_code != 0 or not (is-activated $app) {
    error make {msg: "BetterDisplay license activation failed"}
  }
}
