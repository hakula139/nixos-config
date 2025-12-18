{
  config,
  lib,
  ...
}:

# ==============================================================================
# Xray (VLESS + REALITY)
# ==============================================================================

let
  cfg = config.hakula.services.xray;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.xray = {
    enable = lib.mkEnableOption "Xray proxy server";
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # Secrets (agenix)
    # ----------------------------------------------------------------------------
    age.secrets.xray-config = {
      file = ../../../secrets/shared/xray-config.json.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.xray = {
      enable = true;
      settingsFile = config.age.secrets.xray-config.path;
    };
  };
}
