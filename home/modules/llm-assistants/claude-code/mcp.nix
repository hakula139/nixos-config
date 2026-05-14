# ==============================================================================
# Claude Code MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  llmAssistantLib,
  secretPath,
  enabledServers,
  ...
}:

let
  json = pkgs.formats.json { };

  inherit (llmAssistantLib) mcpOptions;
  mcp = import ../shared/mcp {
    inherit
      config
      pkgs
      lib
      llmAssistantLib
      corpDomain
      secretPath
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
