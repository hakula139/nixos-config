# ==============================================================================
# LLM Assistants
# ==============================================================================

{ lib }:

let
  mcpOptions = import ../home/modules/llm-assistants/shared/mcp/options.nix { inherit lib; };
  proxyOptions = import ../home/modules/llm-assistants/shared/proxy.nix { inherit lib; };
in
{
  mkOptions =
    {
      enableDescription,
      defaultUser,
    }:
    {
      enable = lib.mkEnableOption enableDescription;

      user = lib.mkOption {
        type = lib.types.str;
        default = defaultUser;
        description = "Home Manager user to receive assistant defaults";
      };

      mcp = {
        disabledServers = mcpOptions.mkDisabledServersOption {
          description = "MCP servers to disable across all LLM assistants";
        };
      };

      proxy = proxyOptions.mkProxyOptions "LLM assistants";
    };

  mkHomeManagerConfig = cfg: {
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
