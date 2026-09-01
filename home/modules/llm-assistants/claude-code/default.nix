# ==============================================================================
# Claude Code Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpHosts,
  hostType,
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
      hostType
      secretPath
      ;
  };

  claudeAgentNames = agentRoleOptions.sharedAgentNames ++ [
    "codex-worker"
    "comment-gate"
  ];
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

      hooks = import ./hooks.nix {
        inherit
          pkgs
          lib
          repo
          enableDevToolchains
          ;
      };

      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          llmAssistantLib
          corpHosts
          proxyLib
          secretPath
          ;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
      };

      plugins = import ./plugins.nix {
        inherit
          pkgs
          lib
          inputs
          enableDevToolchains
          ;
        inherit (cfg.plugins) online;
      };

      agents = import ./agents {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
      };

      # ------------------------------------------------------------------------
      # Status line
      # ------------------------------------------------------------------------
      statusLinePackage = pkgs.writers.writeNuBin "statusline-command" {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.nodejs_24 ])
        ];
      } (builtins.readFile ./scripts/statusline-command.nu);
      statusLineScript = "${statusLinePackage}/bin/statusline-command";

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
          # `--mcp-config` is variadic, so the `=` form is required: the
          # space-separated form swallows the prompt and any subcommand.
          "--add-flags"
          "--mcp-config=${mcp.configFile}"
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
          ".claude/statusline-command" = {
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
            profileSettings = profiles.settings;
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
