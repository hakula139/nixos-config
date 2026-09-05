# ==============================================================================
# Codex MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
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
      corpHosts
      proxyLib
      secretPath
      ;
  };

  fieldRenames = {
    command = "command";
    startupTimeoutSec = "startup_timeout_sec";
    url = "url";
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
