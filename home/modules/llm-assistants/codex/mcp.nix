# ==============================================================================
# Codex MCP Configuration
# ==============================================================================

{
  lib,
  enabledServers,
  mcpOptions,
  mcpServers,
  ...
}:

let
  fieldRenames = {
    command = "command";
    startupTimeoutSec = "startup_timeout_sec";
    url = "url";
  };

  mkEntry =
    name:
    lib.nameValuePair mcpOptions.serverDisplayNames.${name} (
      lib.mapAttrs' (field: toml: lib.nameValuePair toml mcpServers.${name}.${field}) (
        lib.intersectAttrs mcpServers.${name} fieldRenames
      )
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
