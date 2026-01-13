{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

let
  mcp = import ./mcp.nix {
    inherit
      config
      pkgs
      lib
      isNixOS
      ;
  };
in
{
  # ============================================================================
  # Claude Code Configuration
  # ============================================================================
  programs.claude-code = {
    enable = true;

    # --------------------------------------------------------------------------
    # MCP configuration
    # --------------------------------------------------------------------------
    mcpServers = {
      Context7 = mcp.servers.context7;
      DeepWiki = mcp.servers.deepwiki;
    };
  };
}
