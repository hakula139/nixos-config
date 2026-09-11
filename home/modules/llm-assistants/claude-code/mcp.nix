# ==============================================================================
# Claude Code MCP Configuration
# ==============================================================================

{
  pkgs,
  enabledServers,
  mcpOptions,
  mcpServers,
}:

let
  json = pkgs.formats.json { };

  serversConfig = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = mcpServers.${s};
    }) enabledServers
  );

  configFile = json.generate "claude-code-mcp-config.json" {
    mcpServers = serversConfig;
  };
in
{
  inherit configFile;
}
