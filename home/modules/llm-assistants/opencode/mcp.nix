# ==================================================================================================
# OpenCode MCP Configuration
# ==================================================================================================

{
  enabledServers,
  mcpOptions,
  shared,
}:

let
  mkEntry =
    s:
    let
      server = shared.mcp.servers.${s};
    in
    {
      name = mcpOptions.serverDisplayNames.${s};
      value =
        (
          if server.type == "stdio" then
            {
              type = "local";
              command = [ server.command ];
            }
          else
            {
              type = "remote";
              inherit (server) url;
            }
        )
        // {
          timeout = shared.mcp.timeouts.startup * 1000;
        };
    };
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
