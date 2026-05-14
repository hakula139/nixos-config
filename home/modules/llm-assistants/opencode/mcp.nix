# ==============================================================================
# OpenCode MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  corpDomain,
  llmAssistantLib,
  isNixOS ? false,
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
      secrets
      llmAssistantLib
      corpDomain
      isNixOS
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
