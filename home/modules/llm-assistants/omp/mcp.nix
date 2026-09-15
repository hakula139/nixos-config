# ==============================================================================
# OMP MCP Configuration
# ==============================================================================

{
  lib,
  enabledServers,
  mcpOptions,
  mcpServers,
  timeouts,
}:

let
  mkEntry =
    name:
    lib.nameValuePair mcpOptions.serverDisplayNames.${name} (
      mcpServers.${name} // { timeout = timeouts.startup * 1000; }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
