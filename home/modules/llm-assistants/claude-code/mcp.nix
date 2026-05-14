# ==============================================================================
# Claude Code MCP Configuration
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
  json = pkgs.formats.json { };

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

  serversConfig = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = mcp.servers.${s};
    }) enabledServers
  );

  configFile = json.generate "claude-code-mcp-config.json" {
    mcpServers = serversConfig;
  };
in
{
  inherit configFile;
}
