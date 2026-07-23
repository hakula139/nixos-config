# ==============================================================================
# Claude Code Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpDomain,
  llmAssistantLib,
  proxyLib,
  repo,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;

  instructions = import ../shared/instructions;
  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  inherit (llmAssistantLib) mcpOptions;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      secretPath
      ;
  };

  claudeAgentNames = agentRoleOptions.sharedAgentNames ++ [ "codex-worker" ];
  claudeMcpServers = mcpOptions.commonServerNames ++ [ "codex" ];
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

    mcp = mcpOptions.mkMcpOptions { names = claudeMcpServers; };

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

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      permissions = import ./permissions.nix {
        sharedPermissions = llmAssistantLib.permissions;
      };

      notify = import ../shared/notify.nix { inherit pkgs lib; };
      hooks = import ./hooks { inherit pkgs lib repo; };

      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          llmAssistantLib
          corpDomain
          proxyLib
          secretPath
          ;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
      };

      plugins = import ./plugins.nix {
        inherit pkgs lib inputs;
        inherit (cfg.plugins) devToolchains online;
      };

      agents = import ./agents {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
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
      profiles.config

      {
        home.file = {
          ".claude/CLAUDE.md".text = instructions.claudeCode;
          ".claude/statusline-command.sh" = {
            source = statusLineScript;
            executable = true;
          };
        }
        // profiles.homeFiles;

        home.packages = profiles.packages;
        home.activation.claudeCodeProfile = profiles.activation;

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
