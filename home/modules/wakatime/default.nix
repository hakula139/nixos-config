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
in
{
  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  config = lib.mkIf (!isNixOS) {
    hakula.secrets.required = {
      "wakatime/config" = {
        path = "${homeDir}/.wakatime.cfg";
      };
    };
  };
}
