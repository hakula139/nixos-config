# ==============================================================================
# WakaTime Configuration
# ==============================================================================

{
  config,
  lib,
  isNixOS ? false,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  requiredSecrets = {
    "wakatime/config" = {
      path = "${homeDir}/.wakatime.cfg";
    };
  };
in
{
  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  config = lib.mkIf (!isNixOS) {
    hakula.secrets.required = requiredSecrets;
  };
}
