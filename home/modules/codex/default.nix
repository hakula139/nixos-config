{
  config,
  pkgs,
  lib,
  inputs,
  secrets,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Codex Configuration
# ==============================================================================

let
  cfg = config.hakula.codex;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI";

    proxy = {
      enable = lib.mkEnableOption "HTTP proxy for Codex";
      url = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:7897";
        description = "HTTP proxy URL for Codex";
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
      notify = import ../notify { inherit pkgs lib; };

      mcp = import ../mcp {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
      };

      codexPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      noProxy = builtins.concatStringsSep "," cfg.proxy.noProxy;

      codexBin =
        if cfg.proxy.enable then
          pkgs.symlinkJoin {
            # Keep codex version in the derivation name so Home Manager
            # detects this as a modern codex and renders config.toml.
            name = "codex-${codexPkg.version}";
            paths = [ codexPkg ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/codex \
                --set HTTP_PROXY ${lib.escapeShellArg cfg.proxy.url} \
                --set HTTPS_PROXY ${lib.escapeShellArg cfg.proxy.url} \
                --set NO_PROXY ${lib.escapeShellArg noProxy}
            '';
          }
        else
          codexPkg;
    in
    lib.mkMerge [
      mcp.secrets
      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        programs.codex = {
          enable = true;
          package = codexBin;

          # --------------------------------------------------------------------
          # AGENTS.md
          # --------------------------------------------------------------------
          custom-instructions = builtins.readFile ./_AGENTS.md;

          # --------------------------------------------------------------------
          # Settings
          # --------------------------------------------------------------------
          settings = {
            model = "gpt-5.3-codex";
            model_reasoning_effort = "high";
            personality = "pragmatic";

            # ------------------------------------------------------------------
            # Security
            # ------------------------------------------------------------------
            approval_policy = "never";
            sandbox_mode = "danger-full-access";
            web_search = "cached";

            # ------------------------------------------------------------------
            # Notifications
            # ------------------------------------------------------------------
            notify = [
              "${notify.mkProjectNotifyScript}"
              "Codex"
              "Response complete"
            ];

            # ------------------------------------------------------------------
            # MCP servers
            # ------------------------------------------------------------------
            mcp_servers = {
              Context7.command = mcp.servers.context7.command;
              DeepWiki.command = mcp.servers.deepwiki.command;
              Filesystem.command = mcp.servers.filesystem.command;
              Git.command = mcp.servers.git.command;
              GitHub.command = mcp.servers.github.command;
            };

            # ------------------------------------------------------------------
            # Experimental features
            # ------------------------------------------------------------------
            features = {
              apps = true;
              collab = true;
              shell_snapshot = true;
            };
          };
        };
      }
    ]
  );
}
