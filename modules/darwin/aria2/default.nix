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
  esc = lib.escapeShellArg;

  cfg = config.hakula.services.aria2;
  userName = config.hakula.user.name;
  homeConfig = config.home-manager.users.${userName};
  rpcConfig = config.age.secrets.aria2-rpc-config.path;

  arguments = lib.mapAttrsToList (
    name: value: "--${name}=${if lib.isBool value then lib.boolToString value else toString value}"
  ) (homeConfig.programs.aria2.settings // repoLib.aria2.rpcSettings);

  startScript = pkgs.writeShellScript "aria2-rpc" ''
    set -euo pipefail

    # aria2 ignores unreadable config files and would start RPC without its token.
    [[ -r ${esc rpcConfig} && -s ${esc rpcConfig} ]]

    exec ${lib.getExe homeConfig.programs.aria2.package} \
      --conf-path=${esc rpcConfig} \
      --enable-rpc \
      --rpc-allow-origin-all=true \
      ${lib.escapeShellArgs arguments}
  '';
in
{
  imports = [
    ./ariang.nix
  ];

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
        name = "aria2/rpc-config-macbook";
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
          settings = lib.mapAttrs (_: lib.mkDefault) repoLib.aria2.downloadSettings // {
            dir = "${config.home.homeDirectory}/Downloads";
            file-allocation = "none";
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
