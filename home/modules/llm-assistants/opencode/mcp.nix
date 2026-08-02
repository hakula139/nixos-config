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

  mkEntry = s: {
    name = mcpOptions.serverDisplayNames.${s};
    value = {
      type = "local";
      command = [ mcp.servers.${s}.command ];
    };
  };
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
