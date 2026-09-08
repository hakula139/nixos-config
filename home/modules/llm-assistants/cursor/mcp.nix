# ==============================================================================
# Cursor MCP Configuration
# ==============================================================================

{
  pkgs,
  enabledServers,
  llmAssistantLib,
  mcpServers,
  ...
}:

let
  inherit (llmAssistantLib) mcpOptions;

  json = pkgs.formats.json { };

  # ----------------------------------------------------------------------------
  # MCP configuration
  # ----------------------------------------------------------------------------
  mcpConfig.mcpServers = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = mcpServers.${s};
    }) enabledServers
  );
in
{
  mcpJson = json.generate "cursor-mcp.json" mcpConfig;
}
