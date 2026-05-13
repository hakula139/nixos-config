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
  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      secrets
      isNixOS
      ;
  };

  instructions = import ../shared/instructions;
  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  claudeAgentNames = agentRoleOptions.sharedAgentNames ++ [ "codex-worker" ];

  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  claudeMcpServers = [
    "atlassian"
    "braveSearch"
    "codex"
    "deepwiki"
    "fetcher"
    "filesystem"
    "git"
    "github"
    "gitlab"
  ];

  proxyLib = import ../shared/proxy.nix { inherit lib; };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.claude-code = {
    enable = lib.mkEnableOption "Claude Code";

    auth = profiles.options;

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
  };

  config = lib.mkIf cfg.enable (
    let
      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      hooks = import ./hooks.nix { inherit pkgs lib; };
      permissions = import ./permissions.nix;
      plugins = import ./plugins.nix {
        inherit pkgs lib inputs;
        inherit (cfg.plugins) devToolchains online;
        codexEnabled = config.hakula.codex.enable;
      };

      agents = import ./agents {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
        codexEnabled = config.hakula.codex.enable;
      };

      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
        enabledServers = builtins.filter (
          s: !(lib.elem s cfg.mcp.disabledServers) && (s != "codex" || config.hakula.codex.enable)
        ) cfg.mcp.enabledServers;
      };

      notify = import ../shared/notify.nix { inherit pkgs lib; };

      # ------------------------------------------------------------------------
      # Status line
      # ------------------------------------------------------------------------
      statusLineScript = pkgs.writeShellScript "statusline-command" (
        builtins.replaceStrings
          [ "@npx@" "@getTtyNum@" ]
          [
            "${pkgs.nodejs_24}/bin/npx"
            "${notify.getTtyNum}"
          ]
          (builtins.readFile ./scripts/statusline-command.sh)
      );

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      claudeCodePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

      wrapArgs =
        profiles.wrapArgs
        ++ lib.optionals cfg.plugins.bundle [
          "--set"
          "CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL"
          "1"
        ]
        ++ lib.optionals cfg.proxy.enable [
          "--run"
          (proxyLib.mkProxyScript cfg.proxy)
        ]
        ++ [
          "--run"
          "source ${mcp.configGuard}"
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
      profiles.config

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
        }
        // profiles.homeFiles;

        # ----------------------------------------------------------------------
        # Auth profile switching
        # ----------------------------------------------------------------------
        home.packages = profiles.packages;
        home.activation.claudeCodeProfile = profiles.activation;

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
            effortLevel = "xhigh";

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
              CLAUDE_CODE_AUTO_COMPACT_WINDOW = "400000";
              CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
              CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
              CLAUDE_CODE_NO_FLICKER = "1";
              CLAUDE_CODE_SCROLL_SPEED = "1";
              DISABLE_INSTALLATION_CHECKS = "1";
              ENABLE_CLAUDEAI_MCP_SERVERS = "0";
              ENABLE_PROMPT_CACHING_1H = "1";
              ENABLE_TOOL_SEARCH = "1";
              FORCE_AUTOUPDATE_PLUGINS = if cfg.plugins.bundle then "0" else "1";
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
