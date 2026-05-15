# ==============================================================================
# OpenCode MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  llmAssistantLib,
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
      corpDomain
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
