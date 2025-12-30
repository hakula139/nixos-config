{
  config,
  pkgs,
  ...
}:

# ==============================================================================
# Cursor MCP (Model Context Protocol) Configuration
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  homeDir = config.home.homeDirectory;

  # ----------------------------------------------------------------------------
  # GitKraken MCP
  # ----------------------------------------------------------------------------
  gitKrakenPath =
    if isDarwin then
      "${homeDir}/Library/Application Support/Cursor/User/globalStorage/eamodio.gitlens/gk"
    else
      "${homeDir}/.config/Cursor/User/globalStorage/eamodio.gitlens/gk";

  # ----------------------------------------------------------------------------
  # Brave Search MCP
  # ----------------------------------------------------------------------------
  # You need to manually decrypt secrets/shared/brave-api-key.age to this path.
  braveApiKeyFile = "${homeDir}/.secrets/brave-api-key";

  braveSearch = pkgs.writeShellScriptBin "brave-search-mcp" ''
    if [ -f "${braveApiKeyFile}" ]; then
      export BRAVE_API_KEY="$(cat ${braveApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-brave-search "$@"
  '';

  # ----------------------------------------------------------------------------
  # MCP Configuration
  # ----------------------------------------------------------------------------
  mcpConfig = {
    mcpServers = {
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
        env = { };
      };
      BraveSearch = {
        name = "BraveSearch";
        command = "${braveSearch}/bin/brave-search-mcp";
        type = "stdio";
        args = [ ];
        env = { };
      };
      DeepWiki = {
        name = "DeepWiki";
        url = "https://mcp.deepwiki.com/sse";
      };
    };
  };
in
{
  # ============================================================================
  # MCP Configuration Generation
  # ============================================================================
  mcpJson = (pkgs.formats.json { }).generate "cursor-mcp.json" mcpConfig;
}
