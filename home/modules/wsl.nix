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
  gatewayProfile = "corp-gateway-anthropic";

  useGatewayProfile =
    config.hakula.llm-assistants.auth.enableCorpGateway
    && repoLib.isConfiguredAgentProfileEnabled config.agents "claude-code" gatewayProfile;
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
    hakula.llm-assistants.enable = lib.mkDefault true;

    agents = {
      claude-code.auth.defaultProfile = lib.mkIf useGatewayProfile (lib.mkDefault gatewayProfile);

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
