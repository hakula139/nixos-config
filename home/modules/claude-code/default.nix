{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  enableDevToolchains ? false,
  ...
}:

# ==============================================================================
# Claude Code Configuration
# ==============================================================================

let
  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.claude-code = {
    enable = lib.mkEnableOption "Claude Code";

    auth = {
      useOAuthToken = lib.mkEnableOption "long-lived OAuth token for authentication";
    };

    proxy = {
      enable = lib.mkEnableOption "HTTP proxy for Claude Code";

      url = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:7897";
        description = "HTTP proxy URL for Claude Code";
      };

      noProxy = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "localhost"
          "127.0.0.1"
        ];
        description = "Domains to bypass the proxy";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      hooks = import ./hooks { inherit pkgs lib; };
      permissions = import ./permissions.nix;
      plugins = import ./plugins.nix { inherit lib enableDevToolchains; };

      mcp = import ../mcp {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
      };

      statusLineScript = pkgs.writeShellScript "statusline-command" (
        builtins.replaceStrings [ "@npx@" ] [ "${pkgs.nodejs}/bin/npx" ] (
          builtins.readFile ./statusline-command.sh
        )
      );

      oauthTokenFile = "${secretsDir}/claude-code-oauth-token";
      claudeCodeBin = pkgs.writeShellScriptBin "claude" (
        lib.optionalString cfg.auth.useOAuthToken ''
          if [ -f "${oauthTokenFile}" ]; then
            export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${oauthTokenFile})"
          fi
        ''
        + ''
          exec ${pkgs.unstable.claude-code}/bin/claude "$@"
        ''
      );
    in
    lib.mkMerge [
      mcp.secrets
      (lib.mkIf (!isNixOS && cfg.auth.useOAuthToken) {
        # ----------------------------------------------------------------------
        # Secrets
        # ----------------------------------------------------------------------
        age.secrets.claude-code-oauth-token = secrets.mkHomeSecret {
          name = "claude-code-oauth-token";
          inherit homeDir;
        };
      })
      {
        # ----------------------------------------------------------------------
        # User configuration files
        # ----------------------------------------------------------------------
        home.file.".claude/CLAUDE.md".source = ./_CLAUDE.md;

        home.file.".claude/statusline-command.sh" = {
          source = statusLineScript;
          executable = true;
        };

        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        programs.claude-code = {
          enable = true;
          package = claudeCodeBin;

          # --------------------------------------------------------------------
          # Settings
          # --------------------------------------------------------------------
          settings = {
            inherit hooks permissions;
            inherit (plugins) enabledPlugins extraKnownMarketplaces;

            attribution = {
              commit = "";
              pr = "";
            };

            env = {
              CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
              DISABLE_INSTALLATION_CHECKS = "1";
              ENABLE_INCREMENTAL_TUI = "true";
              FORCE_AUTOUPDATE_PLUGINS = "true";
            }
            // lib.optionalAttrs cfg.proxy.enable {
              HTTP_PROXY = cfg.proxy.url;
              HTTPS_PROXY = cfg.proxy.url;
              NO_PROXY = builtins.concatStringsSep "," cfg.proxy.noProxy;
            };

            model = "claude-opus-4-6";

            statusLine = {
              type = "command";
              command = "${homeDir}/.claude/statusline-command.sh";
            };

            theme = "dark";
          };

          # --------------------------------------------------------------------
          # MCP configuration
          # --------------------------------------------------------------------
          mcpServers = {
            DeepWiki = mcp.servers.deepwiki;
            Filesystem = mcp.servers.filesystem;
            Git = mcp.servers.git;
            GitHub = mcp.servers.github;
          };
        };
      }
    ]
  );
}
