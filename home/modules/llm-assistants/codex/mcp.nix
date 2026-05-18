# ==============================================================================
# Codex MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  llmAssistantLib,
  proxyLib,
  secretPath,
  enabledServers,
  ...
}:

let
  inherit (llmAssistantLib) mcpOptions;
  mcp = import ../shared/mcp {
    inherit
      config
      pkgs
      lib
      corpDomain
      proxyLib
      secretPath
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
