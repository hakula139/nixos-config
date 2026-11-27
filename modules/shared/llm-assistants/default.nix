# ==================================================================================================
# LLM Assistants Integration
# ==================================================================================================

{
  config,
  lib,
  inputs,
  repoLib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.llm-assistants = {
    enable = lib.mkEnableOption "LLM assistants for the primary interactive user";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakula.user.name;
      description = "Home Manager user to receive assistant defaults";
    };

    mcp = {
      disabledServers = inputs.agents-nix.lib.mcp.mkDisabledServersOption {
        description = "MCP servers to disable across all LLM assistants";
      };
    };

    proxy = repoLib.proxy.mkProxyOptions "LLM assistants";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home-manager.users.${cfg.user}.hakula.llm-assistants = {
      enable = lib.mkDefault true;
      mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
      proxy = lib.mkIf cfg.proxy.enable {
        enable = lib.mkDefault true;
        url = lib.mkDefault cfg.proxy.url;
        secretUrlFile = lib.mkDefault cfg.proxy.secretUrlFile;
        noProxy = lib.mkDefault cfg.proxy.noProxy;
      };
    };
  };
}
