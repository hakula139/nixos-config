#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Start
# ==================================================================================================

# Update the subscription, then replace this process with mihomo. A failed update falls back to the
# previous config when one exists, and fails the start when none does.
def main [
  --config-dir: path # Wrapper-supplied mihomo config directory
] {
  print "Updating config before start..."
  try {
    ^mihomo-update
  } catch {
    if (($config_dir | path join "config.yaml") | path exists) {
      print --stderr "Warning: subscription update failed, starting mihomo from the previous config"
    } else {
      print --stderr $"Error: subscription update failed and no config exists in ($config_dir)"
      exit 1
    }
  }

  print "Starting mihomo..."
  exec mihomo -d $config_dir
}
