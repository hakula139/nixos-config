{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Cursor MCP Configuration
# ==============================================================================

let
  json = pkgs.formats.json { };

  mcp = import ../mcp {
    inherit
      config
      pkgs
      lib
      secrets
      isNixOS
      ;
  };

  # ----------------------------------------------------------------------------
  # MCP configuration
  # ----------------------------------------------------------------------------
  mcpConfig = {
    mcpServers = {
      DeepWiki = mcp.servers.deepwiki;
      Filesystem = mcp.servers.filesystem;
      Git = mcp.servers.git;
      GitHub = mcp.servers.github;
    };
  };
in
{
  inherit (mcp) secrets;
  mcpJson = json.generate "cursor-mcp.json" mcpConfig;
}
