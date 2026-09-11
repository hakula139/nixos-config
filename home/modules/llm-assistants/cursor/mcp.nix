# ==============================================================================
# Cursor MCP Configuration
# ==============================================================================

{
  pkgs,
  enabledServers,
  mcpOptions,
  mcpServers,
}:

let
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
