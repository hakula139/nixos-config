{
  config,
  pkgs,
  lib,
  inputs,
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

      notify = import ../notify { inherit pkgs lib; };

      statusLineScript = pkgs.writeShellScript "statusline-command" (
        builtins.replaceStrings [ "@npx@" "@getTtyNum@" ] [ "${pkgs.nodejs}/bin/npx" "${notify.getTtyNum}" ]
          (builtins.readFile ./statusline-command.sh)
      );

      claudeCodePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      oauthTokenFile = "${secretsDir}/claude-code-oauth-token";

      claudeCodeBin =
        if cfg.auth.useOAuthToken then
          pkgs.symlinkJoin {
            name = "claude-code-${claudeCodePkg.version}";
            paths = [ claudeCodePkg ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/claude \
                --run '[ -f "${oauthTokenFile}" ] && export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${oauthTokenFile})"'
            '';
          }
        else
          claudeCodePkg;
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

            model = "claude-opus-4-6";

            theme = "dark";
            statusLine = {
              type = "command";
              command = "${homeDir}/.claude/statusline-command.sh";
            };

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
          };

          # --------------------------------------------------------------------
          # MCP servers
          # --------------------------------------------------------------------
          mcpServers = {
            DeepWiki = mcp.servers.deepwiki;
            Filesystem = mcp.servers.filesystem;
            Git = mcp.servers.git;
            GitHub = mcp.servers.github;
          }
          // lib.optionalAttrs config.hakula.codex.enable {
            Codex = mcp.servers.codex;
          };
        };
      }
    ]
  );
}
