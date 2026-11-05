# ==================================================================================================
# Codex MCP Configuration
# ==================================================================================================

{
  lib,
  enabledServers,
  mcpApprovals,
  mcpOptions,
  shared,
}:

let
  fieldRenames = {
    command = "command";
    url = "url";
  };

  mkEntry =
    name:
    lib.nameValuePair mcpOptions.serverDisplayNames.${name} (
      {
        startup_timeout_sec = shared.mcp.timeouts.startup;
      }
      // lib.mapAttrs' (field: toml: lib.nameValuePair toml shared.mcp.servers.${name}.${field}) (
        lib.intersectAttrs shared.mcp.servers.${name} fieldRenames
      )
      // mcpApprovals.${name} or { }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
