#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Update Reload
# ==================================================================================================

# Update the subscription, then signal the mihomo launchd agent to reload its config.
def main [
  --label: string # Wrapper-supplied launchd label of the mihomo agent
] {
  ^mihomo-update

  ^launchctl kill SIGHUP $"gui/(^id -u | str trim)/($label)"
}
