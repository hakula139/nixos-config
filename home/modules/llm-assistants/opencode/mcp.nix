# ==============================================================================
# OpenCode MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  llmAssistantLib,
  proxyLib,
  secretPath,
  enabledServers,
  ...
}:

let
  inherit (llmAssistantLib) mcpOptions;
  mcp = import ../shared/mcp {
    inherit
      config
      pkgs
      lib
      corpHosts
      proxyLib
      secretPath
      ;
  };

  mkEntry =
    s:
    let
      server = mcp.servers.${s};
    in
    {
      name = mcpOptions.serverDisplayNames.${s};
      value =
        if server.type == "stdio" then
          {
            type = "local";
            command = [ server.command ];
          }
        else
          {
            type = "remote";
            inherit (server) url;
          };
    };
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
