# ==============================================================================
# AriaNg (Aria2 Web Interface)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.aria2;
  userName = config.hakula.user.name;
  port = 6801;
  url = "http://127.0.0.1:${toString port}/";

  assets = pkgs.runCommand "ariang-provisioned" { } ''
    cp -R ${pkgs.ariang}/share/ariang "$out"
    chmod -R u+w "$out"
    cp ${./ariang-config.js} "$out/js/ariang-config.js"
    substituteInPlace "$out/index.html" \
      --replace-fail '</body>' '<script src="js/ariang-config.js"></script></body>'
  '';
  serverConfig = (pkgs.formats.json { }).generate "ariang-server.json" {
    inherit assets port;
    rpcPort = repoLib.aria2.rpcSettings.rpc-listen-port;
    rpcConfig = config.age.secrets.aria2-rpc-config.path;
  };
  server = pkgs.writers.writePython3 "ariang-server" { } (builtins.readFile ./ariang-server.py);

  openUi = pkgs.writeShellScriptBin "ariang" ''
    exec /usr/bin/open ${lib.escapeShellArg url}
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.aria2.webUi.enable = lib.mkEnableOption "AriaNg web interface for aria2";

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf (cfg.enable && cfg.webUi.enable) {
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
            "${server}"
            "${serverConfig}"
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
