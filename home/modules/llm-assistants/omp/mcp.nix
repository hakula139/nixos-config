# ==================================================================================================
# OMP MCP Configuration
# ==================================================================================================

{
  lib,
  enabledServers,
  mcpOptions,
  shared,
}:

let
  mkEntry =
    name:
    lib.nameValuePair mcpOptions.serverDisplayNames.${name} (
      shared.mcp.servers.${name} // { timeout = shared.mcp.timeouts.startup * 1000; }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
