# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  lib,
}:

let
  mcpOptions = import ./mcp-options.nix {
    inherit lib;
  };

  # Runtime transcripts record either the catalog key, the `<route>/<id>` channel ID, or the
  # route-stripped ID returned by the corporate gateway.
  channelIds =
    channelId:
    let
      stripped = builtins.match "[^/]+/(.+)" channelId;
    in
    lib.unique ([ channelId ] ++ lib.optional (stripped != null) (builtins.head stripped));
in
{
  inherit
    channelIds
    mcpOptions
    ;

  mkPermissions =
    { corpHosts }:
    import ./permissions {
      inherit lib corpHosts mcpOptions;
    };
  mkProfileDefinitions = import ./profiles.nix;

  mkOptions =
    {
      mkProxyOptions,
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

      proxy = mkProxyOptions "LLM assistants";
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
