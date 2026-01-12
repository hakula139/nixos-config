{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  isDesktop ? false,
  secretsDir ? "${config.home.homeDirectory}/.secrets",
  ...
}:

# ==============================================================================
# Cursor MCP (Model Context Protocol)
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  homeDir = config.home.homeDirectory;
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
  # GitKraken MCP
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
      BraveSearch = {
        name = "BraveSearch";
        inherit (mcp.servers.braveSearch) command type;
      };

      Context7 = {
        name = "Context7";
        inherit (mcp.servers.context7) command type;
      };

      DeepWiki = {
        name = "DeepWiki";
        inherit (mcp.servers.deepwiki) command type;
      };

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
    };
  };
in
{
  secrets = mcp.secrets;
  mcpJson = (pkgs.formats.json { }).generate "cursor-mcp.json" mcpConfig;
}
