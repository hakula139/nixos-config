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
      notify = import ../shared/notify.nix { inherit pkgs lib; };
      permissions = import ./permissions.nix;

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

      plugins = import ./plugins.nix {
        inherit pkgs lib inputs;
        inherit (cfg.plugins) devToolchains online;
        codexEnabled = config.hakula.codex.enable;
      };

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

      # home-manager's programs.claude-code.mcpServers injection trips
      # Commander.js's variadic parsing, which eats subcommand names as
      # config paths. Inject --mcp-config here, skipping for subcommands.
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
        set -- --mcp-config ${mcp.configFile} "$@"
      '';

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

          settings = import ./settings.nix {
            inherit
              lib
              homeDir
              hooks
              permissions
              plugins
              ;
            bundlePlugins = cfg.plugins.bundle;
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
