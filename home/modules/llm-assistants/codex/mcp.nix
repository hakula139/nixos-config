# ==============================================================================
# Codex MCP Configuration
# ==============================================================================

{
  lib,
  enabledServers,
  mcpOptions,
  mcpServers,
  timeouts,
  ...
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
        startup_timeout_sec = timeouts.startup;
      }
      // lib.mapAttrs' (field: toml: lib.nameValuePair toml mcpServers.${name}.${field}) (
        lib.intersectAttrs mcpServers.${name} fieldRenames
      )
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
