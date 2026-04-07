# ==============================================================================
# Claude Code Configuration
# ==============================================================================

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

let
  json = pkgs.formats.json { };

  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;
  corpDomain = import ../../../../lib/corp-domain.nix;

  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  claudeAgentNames = agentRoleOptions.sharedAgentNames ++ [ "codex-worker" ];
  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  proxyLib = import ../shared/proxy.nix { inherit lib; };
  instructions = import ../shared/instructions;
  claudeMcpServers = [
    "atlassian"
    "codex"
    "deepwiki"
    "fetcher"
    "filesystem"
    "git"
    "github"
    "gitlab"
  ];
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

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        names = claudeAgentNames;
        default = claudeAgentNames;
        description = "Custom agents to enable";
      };
    };

    mcp = {
      enabledServers = mcpOptions.mkEnabledServersOption {
        names = claudeMcpServers;
        description = "MCP servers to enable";
      };
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable";
      };
    };

    plugins = {
      bundle = lib.mkEnableOption "pre-bundled plugins (for air-gapped deployment)";

      devToolchains = lib.mkOption {
        type = lib.types.bool;
        default = enableDevToolchains;
        description = "Whether to enable dev toolchain LSP plugins (clangd, gopls, rust-analyzer)";
      };

      online = lib.mkOption {
        type = lib.types.bool;
        default = !cfg.plugins.bundle;
        description = "Whether to enable plugins requiring internet access (context7, agent-browser)";
      };
    };

    proxy = proxyLib.mkProxyOptions "Claude Code";

    gateway = {
      enable = lib.mkEnableOption "internal LiteLLM gateway";

      url = lib.mkOption {
        type = lib.types.str;
        default = "https://gw.llm.${corpDomain}/";
        description = "LiteLLM gateway base URL";
      };

      models = {
        opus = lib.mkOption {
          type = lib.types.str;
          default = "bedrock/global.anthropic.claude-opus-4-6-v1";
          description = "Opus model identifier for the gateway";
        };
        sonnet = lib.mkOption {
          type = lib.types.str;
          default = "bedrock/global.anthropic.claude-sonnet-4-6";
          description = "Sonnet model identifier for the gateway";
        };
        haiku = lib.mkOption {
          type = lib.types.str;
          default = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
          description = "Haiku model identifier for the gateway";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      hooks = import ./hooks { inherit pkgs lib; };
      permissions = import ./permissions.nix;
      plugins = import ./plugins.nix {
        inherit lib pkgs;
        inherit (cfg.plugins) devToolchains online;
      };

      agents = import ./agents {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
        codexEnabled = config.hakula.codex.enable;
      };

      mcp = import ../shared/mcp {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
      };

      notify = import ../shared/notify.nix { inherit pkgs lib; };

      # ------------------------------------------------------------------------
      # Status line
      # ------------------------------------------------------------------------
      statusLineScript = pkgs.writeShellScript "statusline-command" (
        builtins.replaceStrings
          [ "@npx@" "@getTtyNum@" ]
          [
            "${pkgs.nodejs}/bin/npx"
            "${notify.getTtyNum}"
          ]
          (builtins.readFile ./statusline-command.sh)
      );

      # ------------------------------------------------------------------------
      # MCP server selection
      # ------------------------------------------------------------------------
      # Codex requires the codex module to be enabled
      effectiveServers = builtins.filter (
        s: !(lib.elem s cfg.mcp.disabledServers) && (s != "codex" || config.hakula.codex.enable)
      ) cfg.mcp.enabledServers;

      mcpServersConfig = builtins.listToAttrs (
        map (s: {
          name = mcpOptions.serverDisplayNames.${s};
          value = mcp.servers.${s};
        }) effectiveServers
      );

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      claudeCodePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      oauthTokenFile = lib.escapeShellArg "${secretsDir}/claude-code-oauth-token";
      gatewayKeyFile = lib.escapeShellArg "${secretsDir}/litellm-api-key";
      gatewayCaCertFile = "${secretsDir}/corp-cachain-crt";

      mcpConfigFile = json.generate "claude-code-mcp-config.json" {
        mcpServers = mcpServersConfig;
      };

      # Workaround: home-manager's programs.claude-code.mcpServers injects
      # --mcp-config via --append-flags, but Commander.js's variadic option
      # parsing greedily consumes subcommand names (setup-token, auth, etc.)
      # as config file paths. We handle --mcp-config ourselves, skipping it
      # when a subcommand is detected.
      mcpConfigGuard = pkgs.writeShellScript "claude-mcp-config-guard" ''
        for __cc_arg in "$@"; do
          case "$__cc_arg" in
            agents|auth|doctor|install|mcp|plugin|plugins|setup-token|update|upgrade)
              return 0
              ;;
            --)
              break
              ;;
          esac
        done
        set -- --mcp-config ${mcpConfigFile} "$@"
      '';

      wrapArgs =
        lib.optionals cfg.auth.useOAuthToken [
          "--run"
          ''export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${oauthTokenFile})"''
        ]
        ++ lib.optionals cfg.gateway.enable [
          "--run"
          ''export ANTHROPIC_AUTH_TOKEN="$(cat ${gatewayKeyFile})"''
          "--set"
          "NODE_EXTRA_CA_CERTS"
          gatewayCaCertFile
        ]
        ++ lib.optionals cfg.proxy.enable [
          "--run"
          (proxyLib.mkProxyScript cfg.proxy)
        ]
        ++ lib.optionals cfg.plugins.bundle [
          "--set"
          "CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL"
          "1"
        ]
        ++ [
          "--run"
          "source ${mcpConfigGuard}"
        ];

      claudeCodeBin = pkgs.symlinkJoin {
        name = "claude-code-${claudeCodePkg.version}";
        paths = [ claudeCodePkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude ${lib.escapeShellArgs wrapArgs}
        '';
      };

      # ------------------------------------------------------------------------
      # Plugin bundling
      # ------------------------------------------------------------------------
      pluginBundle = plugins.mkPluginBundle homeDir;
    in
    lib.mkMerge [
      mcp.secrets
      {
        assertions = [
          {
            assertion = !(cfg.gateway.enable && cfg.auth.useOAuthToken);
            message = "hakula.claude-code: gateway and OAuth token auth are mutually exclusive";
          }
        ];
      }
      (lib.mkIf (!isNixOS && cfg.auth.useOAuthToken) {
        # ----------------------------------------------------------------------
        # Secrets
        # ----------------------------------------------------------------------
        age.secrets.claude-code-oauth-token = secrets.mkHomeSecret {
          name = "claude-code-oauth-token";
          inherit homeDir;
        };
      })
      (lib.mkIf (!isNixOS && cfg.gateway.enable) {
        age.secrets.litellm-api-key = secrets.mkHomeSecret {
          name = "litellm-api-key";
          inherit homeDir;
        };
        age.secrets.corp-cachain-crt = secrets.mkHomeSecret {
          name = "corp-cachain-crt";
          inherit homeDir;
        };
      })

      {
        # ----------------------------------------------------------------------
        # User configuration files
        # ----------------------------------------------------------------------
        home.file = {
          ".claude/CLAUDE.md".text = instructions.claudeCode;
          ".claude/statusline-command.sh" = {
            source = statusLineScript;
            executable = true;
          };
        };

        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        programs.claude-code = {
          enable = true;
          package = claudeCodeBin;
          inherit agents;

          # --------------------------------------------------------------------
          # Settings
          # --------------------------------------------------------------------
          settings = {
            # ------------------------------------------------------------------
            # Hooks / permissions / plugins
            # ------------------------------------------------------------------
            inherit hooks permissions;
            inherit (plugins) enabledPlugins;
          }
          # When bundling, known_marketplaces.json handles discovery;
          # extraKnownMarketplaces in settings would trigger failed GitHub installs.
          // lib.optionalAttrs (!cfg.plugins.bundle) {
            inherit (plugins) extraKnownMarketplaces;
          }
          // {
            # ------------------------------------------------------------------
            # Model
            # ------------------------------------------------------------------
            model = "opus[1m]";
            effortLevel = "high";

            # ------------------------------------------------------------------
            # Project
            # ------------------------------------------------------------------
            plansDirectory = "./.claude/plans";
            attribution = {
              commit = "";
              pr = "";
            };

            # ------------------------------------------------------------------
            # Interface
            # ------------------------------------------------------------------
            theme = "dark";
            statusLine = {
              type = "command";
              command = "${homeDir}/.claude/statusline-command.sh";
            };

            # ------------------------------------------------------------------
            # Environment
            # ------------------------------------------------------------------
            env = {
              CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "95";
              CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
              CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
              DISABLE_INSTALLATION_CHECKS = "1";
              ENABLE_CLAUDEAI_MCP_SERVERS = "false";
              FORCE_AUTOUPDATE_PLUGINS = if cfg.plugins.bundle then "false" else "true";
            }
            // lib.optionalAttrs cfg.gateway.enable {
              ANTHROPIC_BASE_URL = cfg.gateway.url;
              API_TIMEOUT_MS = "3000000";
              ANTHROPIC_DEFAULT_HAIKU_MODEL = cfg.gateway.models.haiku;
              ANTHROPIC_DEFAULT_SONNET_MODEL = cfg.gateway.models.sonnet;
              ANTHROPIC_DEFAULT_OPUS_MODEL = cfg.gateway.models.opus;
            };
          };
        };
      }

      # ------------------------------------------------------------------------
      # Plugin bundling (air-gapped deployment)
      # ------------------------------------------------------------------------
      (lib.mkIf cfg.plugins.bundle {
        home.file = {
          ".claude/plugins/cache" = {
            source = "${pluginBundle}/cache";
            recursive = true;
          };
          ".claude/plugins/marketplaces" = {
            source = "${pluginBundle}/marketplaces";
            recursive = true;
          };
          ".claude/plugins/installed_plugins.json" = {
            source = "${pluginBundle}/installed_plugins.json";
          };
          ".claude/plugins/known_marketplaces.json" = {
            source = "${pluginBundle}/known_marketplaces.json";
          };
        };
      })
    ]
  );
}
