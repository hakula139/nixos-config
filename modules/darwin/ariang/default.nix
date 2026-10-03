# ==============================================================================
# AriaNg (Aria2 Web Interface)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.hakula.services.ariang;
  userName = config.hakula.user.name;
  port = 6801;
  url = "http://127.0.0.1:${toString port}/";

  openUi = pkgs.writeShellScriptBin "ariang" ''
    exec /usr/bin/open ${lib.escapeShellArg url}
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.ariang.enable = lib.mkEnableOption "AriaNg web interface";

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home-manager.users.${userName} = {
      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
      home.packages = [ openUi ];

      # ------------------------------------------------------------------------
      # Launchd agents (macOS)
      # ------------------------------------------------------------------------
      launchd.agents.ariang = {
        enable = true;
        config = {
          ProgramArguments = [
            (lib.getExe pkgs.darkhttpd)
            "${pkgs.ariang}/share/ariang"
            "--addr"
            "127.0.0.1"
            "--port"
            (toString port)
            "--no-listing"
          ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          ProcessType = "Background";
          ThrottleInterval = 30;
        };
      };
    };
  };
}
