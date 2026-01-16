{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Claude Code Configuration
# ==============================================================================

let
  proxy = "http://127.0.0.1:7897";
  hooks = import ./hooks.nix;
  permissions = import ./permissions.nix;
  plugins = import ./plugins.nix;
  mcp = import ../mcp.nix {
    inherit
      config
      pkgs
      lib
      isNixOS
      ;
  };

  statusLineScript = pkgs.writeShellScript "statusline-command" (
    builtins.replaceStrings [ "@npx@" ] [ "${pkgs.nodejs}/bin/npx" ] (
      builtins.readFile ./statusline-command.sh
    )
  );
in
lib.mkMerge [
  mcp.secrets
  {
    # --------------------------------------------------------------------------
    # User configuration files
    # --------------------------------------------------------------------------
    home.file.".claude/CLAUDE.md".source = ./_CLAUDE.md;

    home.file.".claude/statusline-command.sh" = {
      source = statusLineScript;
      executable = true;
    };

    # --------------------------------------------------------------------------
    # Program configuration
    # --------------------------------------------------------------------------
    programs.claude-code = {
      enable = true;
      package = pkgs.unstable.claude-code;

      # ------------------------------------------------------------------------
      # Settings
      # ------------------------------------------------------------------------
      settings = {
        inherit hooks permissions;
        inherit (plugins) enabledPlugins extraKnownMarketplaces;

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

        statusLine = {
          type = "command";
          command = "${config.home.homeDirectory}/.claude/statusline-command.sh";
        };

        theme = "dark";
      };

      # ------------------------------------------------------------------------
      # MCP configuration
      # ------------------------------------------------------------------------
      mcpServers = {
        Context7 = mcp.servers.context7;
        DeepWiki = mcp.servers.deepwiki;
        Filesystem = mcp.servers.filesystem;
        Git = mcp.servers.git;
        Playwright = mcp.servers.playwright;
      };
    };
  }
]
