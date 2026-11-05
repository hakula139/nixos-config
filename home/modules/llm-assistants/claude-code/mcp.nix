# ==================================================================================================
# Claude Code MCP Configuration
# ==================================================================================================

{
  pkgs,
  enabledServers,
  mcpOptions,
  shared,
}:

let
  json = pkgs.formats.json { };

  serversConfig = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = shared.mcp.servers.${s};
    }) enabledServers
  );

  configFile = json.generate "claude-code-mcp-config.json" {
    mcpServers = serversConfig;
  };
in
{
  inherit configFile;
}
