# ==============================================================================
# OpenCode MCP Configuration
# ==============================================================================

{
  lib,
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
        // lib.optionalAttrs (server ? startupTimeoutSec) {
          timeout = server.startupTimeoutSec * 1000;
        };
    };
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
