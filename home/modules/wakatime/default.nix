# ==============================================================================
# WakaTime Configuration
# ==============================================================================

{
  config,
  lib,
  isDesktop ? false,
  ...
}:

let
  homeDir = config.home.homeDirectory;
in
{
  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  config = lib.mkIf isDesktop {
    hakula.secrets.required = {
      "wakatime/config" = {
        path = "${homeDir}/.wakatime.cfg";
      };
    };
  };
}
