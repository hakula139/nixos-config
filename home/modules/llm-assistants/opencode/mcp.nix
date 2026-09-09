# ==============================================================================
# OpenCode MCP Configuration
# ==============================================================================

{
  enabledServers,
  mcpOptions,
  mcpServers,
  startupTimeoutSec,
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
          timeout = startupTimeoutSec * 1000;
        };
    };
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
