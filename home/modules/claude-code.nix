{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

let
  proxy = "http://127.0.0.1:7897";
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

        env = {
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 1;
          HTTPS_PROXY = proxy;
          HTTP_PROXY = proxy;
          NO_PROXY = "localhost,127.0.0.1";
        };

        permissions = {
          defaultMode = "acceptEdits";

          allow = [
            # Local shell
            "Bash(ls:*)"
            "Bash(tree:*)"
            "Bash(cat:*)"
            "Bash(grep:*)"
            "Bash(find:*)"
            "Bash(mv:*)"
            "Bash(cp:*)"
            "Bash(curl:*)"
            "Bash(wget:*)"
            "Bash(git status:*)"
            "Bash(git diff:*)"
            "Bash(git add:*)"
            "Bash(git log:*)"
            "Bash(git show:*)"

            # MCP
            "mcp__BraveSearch__*"
            "mcp__Context7__*"
            "mcp__DeepWiki__*"
            "mcp__Filesystem__*"
            "mcp__Git__status"
            "mcp__Git__diff*"
            "mcp__Git__add"
            "mcp__Git__log"
            "mcp__Git__show"
            "mcp__Git__branch"
            "mcp__Playwright__*"
          ];

          ask = [
            # Local shell
            "Bash(sudo:*)"
            "Bash(rm:*)"
            "Bash(nix:*::*)"
            "Bash(home-manager:*)"
            "Bash(nixos-rebuild:*)"
            "Bash(darwin-rebuild:*)"

            # MCP
            "mcp__Git__commit"
            "mcp__Git__reset"
            "mcp__Git__create_branch"
            "mcp__Git__checkout"
          ];

          deny = [
          ];
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
