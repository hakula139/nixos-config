# ==================================================================================================
# WSL Workstation Bundle
# ==================================================================================================

{
  config,
  lib,
  corpHosts,
  ...
}:

let
  inherit (corpHosts) wildcardDomain;
  inherit (config.agents.claude-code.auth) enabledProfiles;

  cfg = config.hakula.wsl;
  gatewayProfile = "corp-gateway-anthropic";

  useGatewayProfile =
    config.hakula.llm-assistants.auth.enableCorpGateway
    && (enabledProfiles == null || lib.elem gatewayProfile enabledProfiles);
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
    hakula.llm-assistants = {
      enable = lib.mkDefault true;
      proxy.noProxy = lib.mkDefault [
        wildcardDomain
      ];
    };

    agents.claude-code.auth.defaultProfile = lib.mkIf useGatewayProfile (lib.mkDefault gatewayProfile);

    hakula.cursor = {
      extensions.prune = lib.mkForce false;
      windowsSync.enable = lib.mkDefault true;
      mirroredNetworking.enable = lib.mkDefault true;
    };

    hakula.zed.windowsSync.enable = lib.mkDefault true;

    hakula.fonts.windowsSync.enable = lib.mkDefault true;
  };
}
