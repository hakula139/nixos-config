{
  config,
  lib,
  secrets,
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
        description = "Port for Xray WebSocket inbound";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------
    age.secrets.xray-config = secrets.mkSecret {
      name = "xray-config.json";
      owner = "root";
      group = "root";
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
