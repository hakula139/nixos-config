{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  secretsDir ? "${config.home.homeDirectory}/.secrets",
  ...
}:

# ==============================================================================
# Claude Code MCP (Model Context Protocol)
# ==============================================================================

let
  mcp = import ../mcp {
    inherit
      config
      pkgs
      lib
      isNixOS
      secretsDir
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
    };
  };
in
{
  secrets = mcp.secrets;
  mcpJson = (pkgs.formats.json { }).generate "claude-code-mcp.json" mcpConfig;
}
