{
  config,
  lib,
  secrets,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Wakatime Configuration
# ==============================================================================

let
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;
in
{
  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  config = lib.mkIf (!isNixOS) {
    age.secrets.wakatime-config = secrets.mkHomeSecret {
      name = "wakatime-config";
      inherit homeDir;
      path = "${secretsDir}/.wakatime.cfg";
    };
  };
}
