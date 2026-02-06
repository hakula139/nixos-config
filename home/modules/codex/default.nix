{
  config,
  pkgs,
  lib,
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

      codexBin = pkgs.writeShellScriptBin "codex" (
        lib.optionalString cfg.proxy.enable ''
          export HTTP_PROXY="${cfg.proxy.url}"
          export HTTPS_PROXY="${cfg.proxy.url}"
          export NO_PROXY="${builtins.concatStringsSep "," cfg.proxy.noProxy}"
        ''
        + ''
          exec ${pkgs.codex}/bin/codex "$@"
        ''
      );
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
            approval_policy = "on-failure";
            sandbox_mode = "danger-full-access";
            personality = "pragmatic";

            notify = [
              "${notify.mkProjectNotifyScript}"
              "Codex"
              "Response complete"
            ];

            # ------------------------------------------------------------------
            # MCP servers
            # ------------------------------------------------------------------
            mcp_servers = {
              DeepWiki.command = mcp.servers.deepwiki.command;
              Filesystem.command = mcp.servers.filesystem.command;
              Git.command = mcp.servers.git.command;
              GitHub.command = mcp.servers.github.command;
            };
          };
        };
      }
    ]
  );
}
