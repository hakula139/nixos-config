# ==============================================================================
# Cursor MCP Configuration
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
  json = pkgs.formats.json { };

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

  # ----------------------------------------------------------------------------
  # MCP configuration
  # ----------------------------------------------------------------------------
  mcpConfig.mcpServers = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = mcp.servers.${s};
    }) enabledServers
  );
in
{
  mcpJson = json.generate "cursor-mcp.json" mcpConfig;
}
