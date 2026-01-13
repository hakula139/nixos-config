{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  isDesktop ? false,
  ...
}:

# ==============================================================================
# Cursor MCP (Model Context Protocol) Configuration
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  homeDir = config.home.homeDirectory;
  mcp = import ../mcp.nix {
    inherit
      config
      pkgs
      lib
      isNixOS
      ;
  };

  # ----------------------------------------------------------------------------
  # GitKraken
  # ----------------------------------------------------------------------------
  gitKrakenPath =
    if isDesktop then
      (
        if isDarwin then
          "${homeDir}/Library/Application Support/Cursor/User/globalStorage/eamodio.gitlens/gk"
        else
          "${homeDir}/.config/Cursor/User/globalStorage/eamodio.gitlens/gk"
      )
    else
      "${homeDir}/.cursor-server/data/User/globalStorage/eamodio.gitlens/gk";

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
      GitKraken = {
        name = "GitKraken";
        command = gitKrakenPath;
        type = "stdio";
        args = [
          "mcp"
          "--host=cursor"
          "--source=gitlens"
          "--scheme=cursor"
        ];
      };
      Playwright = mcp.servers.playwright;
    };
  };
in
{
  secrets = mcp.secrets;
  mcpJson = (pkgs.formats.json { }).generate "cursor-mcp.json" mcpConfig;
}
