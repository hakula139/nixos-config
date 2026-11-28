# ==================================================================================================
# WSL Workstation Bundle
# ==================================================================================================

{
  config,
  lib,
  repoLib,
  corpHosts,
  ...
}:

let
  inherit (corpHosts) wildcardDomain;

  cfg = config.hakula.wsl;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.wsl = {
    enable = lib.mkEnableOption "Hakula's WSL workstation Home Manager bundle";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Home Manager Overrides
    # ----------------------------------------------------------------------------------------------
    agents = {
      claude-code.auth.defaultProfile =
        repoLib.agents.mkGatewayDefaultProfile config "claude-code"
          "corp-gateway-anthropic";
      proxy.noProxy = [ wildcardDomain ];
    };

    hakula.cursor = {
      extensions.prune = lib.mkForce false;
      windowsSync.enable = lib.mkDefault true;
      mirroredNetworking.enable = lib.mkDefault true;
    };

    hakula.zed.windowsSync.enable = lib.mkDefault true;

    hakula.fonts.windowsSync.enable = lib.mkDefault true;
  };
}
