{
  config,
  pkgs,
  isWorkstation ? false,
  ...
}:

# ==============================================================================
# Cursor MCP (Model Context Protocol) Configuration
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  homeDir = config.home.homeDirectory;

  # ----------------------------------------------------------------------------
  # Brave Search MCP
  # ----------------------------------------------------------------------------
  braveApiKeyFile = config.age.secrets.brave-api-key.path;

  braveSearch = pkgs.writeShellScriptBin "brave-search-mcp" ''
    if [ -f "${braveApiKeyFile}" ]; then
      export BRAVE_API_KEY="$(cat ${braveApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-brave-search "$@"
  '';

  # ----------------------------------------------------------------------------
  # Context7 MCP
  # ----------------------------------------------------------------------------
  context7ApiKeyFile = config.age.secrets.context7-api-key.path;

  context7 = pkgs.writeShellScriptBin "context7-mcp" ''
    if [ -f "${context7ApiKeyFile}" ]; then
      export CONTEXT7_API_KEY="$(cat ${context7ApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @upstash/context7-mcp "$@"
  '';

  # ----------------------------------------------------------------------------
  # GitKraken MCP
  # ----------------------------------------------------------------------------
  gitKrakenPath =
    if isWorkstation then
      (
        if isDarwin then
          "${homeDir}/Library/Application Support/Cursor/User/globalStorage/eamodio.gitlens/gk"
        else
          "${homeDir}/.config/Cursor/User/globalStorage/eamodio.gitlens/gk"
      )
    else
      "${homeDir}/.cursor-server/data/User/globalStorage/eamodio.gitlens/gk";

  # ----------------------------------------------------------------------------
  # MCP Configuration
  # ----------------------------------------------------------------------------
  mcpConfig = {
    mcpServers = {
      BraveSearch = {
        name = "BraveSearch";
        command = "${braveSearch}/bin/brave-search-mcp";
        type = "stdio";
      };
      Context7 = {
        name = "Context7";
        command = "${context7}/bin/context7-mcp";
        type = "stdio";
      };
      DeepWiki = {
        name = "DeepWiki";
        url = "https://mcp.deepwiki.com/sse";
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
  # ============================================================================
  # MCP Configuration Generation
  # ============================================================================
  mcpJson = (pkgs.formats.json { }).generate "cursor-mcp.json" mcpConfig;
}
