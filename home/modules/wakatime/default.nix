# ==============================================================================
# Wakatime Configuration
# ==============================================================================

{
  config,
  lib,
  secrets,
  isNixOS ? false,
  ...
}:

let
  homeDir = config.home.homeDirectory;
in
{
  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  config = lib.mkIf (!isNixOS) {
    age.secrets.wakatime-config = secrets.mkHomeSecret {
      name = "wakatime/config";
      inherit homeDir;
      path = "${homeDir}/.wakatime.cfg";
    };
  };
}
