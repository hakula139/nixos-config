# ==============================================================================
# OpenCode MCP Configuration
# ==============================================================================

{
  enabledServers,
  mcpOptions,
  mcpServers,
  ...
}:

let
  mkEntry =
    s:
    let
      server = mcpServers.${s};
    in
    {
      name = mcpOptions.serverDisplayNames.${s};
      value =
        if server.type == "stdio" then
          {
            type = "local";
            command = [ server.command ];
          }
        else
          {
            type = "remote";
            inherit (server) url;
          };
    };
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
