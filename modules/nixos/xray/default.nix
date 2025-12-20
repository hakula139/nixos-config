{
  config,
  lib,
  ...
}:

# ==============================================================================
# Xray (VLESS + REALITY / WebSocket)
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

    ws = {
      enable = lib.mkEnableOption "VLESS + WebSocket mode";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8445;
        description = "Local port for Xray WebSocket inbound";
      };
    };
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

    # ----------------------------------------------------------------------------
    # Xray service
    # ----------------------------------------------------------------------------
    services.xray = {
      enable = true;
      settingsFile = config.age.secrets.xray-config.path;
    };

    # ----------------------------------------------------------------------------
    # Systemd service
    # ----------------------------------------------------------------------------
    systemd.services.xray.restartTriggers = [ config.age.secrets.xray-config.file ];
  };
}
