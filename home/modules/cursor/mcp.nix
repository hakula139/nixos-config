{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Cursor MCP Configuration
# ==============================================================================

let
  mcp = import ../mcp.nix {
    inherit
      config
      pkgs
      lib
      isNixOS
      ;
  };

  # ----------------------------------------------------------------------------
  # MCP configuration
  # ----------------------------------------------------------------------------
  mcpConfig = {
    mcpServers = {
      BraveSearch = mcp.servers.braveSearch;
      Context7 = mcp.servers.context7;
      DeepWiki = mcp.servers.deepwiki;
      Filesystem = mcp.servers.filesystem;
      Git = mcp.servers.git;
      Playwright = mcp.servers.playwright;
    };
  };
in
{
  secrets = mcp.secrets;
  mcpJson = (pkgs.formats.json { }).generate "cursor-mcp.json" mcpConfig;
}
