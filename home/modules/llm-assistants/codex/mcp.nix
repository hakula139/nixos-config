# ==============================================================================
# Codex MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  enabledServers,
  ...
}:

let
  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  mcp = import ../shared/mcp {
    inherit
      config
      pkgs
      lib
      secrets
      isNixOS
      ;
  };

  fieldRenames = {
    command = "command";
    startupTimeoutSec = "startup_timeout_sec";
  };

  mkEntry =
    name:
    lib.nameValuePair mcpOptions.serverDisplayNames.${name} (
      lib.mapAttrs' (field: toml: lib.nameValuePair toml mcp.servers.${name}.${field}) (
        lib.intersectAttrs mcp.servers.${name} fieldRenames
      )
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
