# ==================================================================================================
# Cursor MCP Configuration
# ==================================================================================================

{
  pkgs,
  agentsMcp,
  enabledServers,
}:

let
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # MCP configuration
  # ------------------------------------------------------------------------------------------------
  mcpConfig.mcpServers = builtins.listToAttrs (
    map (s: {
      name = agentsMcp.displayNames.${s};
      value = agentsMcp.servers.${s};
    }) enabledServers
  );
in
{
  mcpJson = json.generate "cursor-mcp.json" mcpConfig;
}
