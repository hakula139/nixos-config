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
lib.mkMerge [
  mcp.secrets
  {
    # ============================================================================
    # Claude Code Configuration
    # ============================================================================
    programs.claude-code = {
      enable = true;

      # --------------------------------------------------------------------------
      # Settings
      # --------------------------------------------------------------------------
      settings = {
        attribution = {
          commit = "";
          pr = "";
        };
        permissions = {
          defaultMode = "acceptEdits";
        };
      };

      # --------------------------------------------------------------------------
      # MCP configuration
      # --------------------------------------------------------------------------
      mcpServers = {
        BraveSearch = mcp.servers.braveSearch;
        Context7 = mcp.servers.context7;
        DeepWiki = mcp.servers.deepwiki;
        Filesystem = mcp.servers.filesystem;
        Git = mcp.servers.git;
        Playwright = mcp.servers.playwright;
      };
    };
  }
]
