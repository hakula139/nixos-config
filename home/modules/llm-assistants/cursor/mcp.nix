# ==================================================================================================
# Cursor MCP Configuration
# ==================================================================================================

{
  pkgs,
  enabledServers,
  mcpOptions,
  shared,
}:

let
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # MCP configuration
  # ------------------------------------------------------------------------------------------------
  mcpConfig.mcpServers = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = shared.mcp.servers.${s};
    }) enabledServers
  );
in
{
  mcpJson = json.generate "cursor-mcp.json" mcpConfig;
}
