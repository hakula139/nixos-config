# ==============================================================================
# OpenCode MCP Configuration
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

  mkEntry = s: {
    name = mcpOptions.serverDisplayNames.${s};
    value = {
      type = "local";
      command = [ mcp.servers.${s}.command ];
    };
  };
in
{
  inherit (mcp) secrets;
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
