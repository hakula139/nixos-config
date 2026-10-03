# ==============================================================================
# Aria2 (Download Utility)
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
  homeConfig = config.home-manager.users.${userName};
  rpcConfig = config.age.secrets.aria2-rpc-config.path;

  downloadArguments = lib.mapAttrsToList (
    name: value: "--${name}=${if lib.isBool value then lib.boolToString value else toString value}"
  ) homeConfig.programs.aria2.settings;

  startScript = pkgs.writeShellScript "aria2-rpc" ''
    set -euo pipefail

    # aria2 ignores unreadable config files and would start RPC without its token.
    [[ -r ${lib.escapeShellArg rpcConfig} && -s ${lib.escapeShellArg rpcConfig} ]]

    exec ${lib.getExe homeConfig.programs.aria2.package} \
      --conf-path=${lib.escapeShellArg rpcConfig} \
      --enable-rpc \
      --rpc-listen-all=false \
      --rpc-allow-origin-all=true \
      ${lib.escapeShellArgs downloadArguments}
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.aria2.enable = lib.mkEnableOption "aria2 RPC server";

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets = lib.mkIf cfg.enable {
      aria2-rpc-config = repoLib.secrets.mkDarwinUserSecret userName {
        name = "aria2/rpc-config";
      };
    };

    home-manager.users.${userName} =
      { config, ... }:
      {
        # ----------------------------------------------------------------------
        # User configuration
        # ----------------------------------------------------------------------
        programs.aria2 = {
          enable = true;
          settings = {
            continue = true;
            dir = "${config.home.homeDirectory}/Downloads";
            file-allocation = "none";
            max-connection-per-server = 4;
            split = 4;
          };
        };

        # ----------------------------------------------------------------------
        # Launchd agents (macOS)
        # ----------------------------------------------------------------------
        launchd.agents.aria2 = lib.mkIf cfg.enable {
          enable = true;
          config = {
            ProgramArguments = [ "${startScript}" ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ProcessType = "Background";
            ThrottleInterval = 30;
            Umask = 63;
          };
        };
      };
  };
}
