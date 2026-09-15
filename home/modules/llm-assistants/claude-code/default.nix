# ==============================================================================
# Claude Code Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  hostType,
  modelCatalog,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  cfg = config.hakula.claude-code;
  shared = config.lib.llmAssistants;

  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  claudeAgentNames = agentRoleOptions.sharedAgentNames ++ [
    "codex-worker"
    "comment-gate"
  ];
  claudeMcpServers = mcpOptions.commonServerNames ++ [ "codex" ];

  agents = import ./agents {
    inherit lib;
    inherit (instructions) commentGate;
    inherit (cfg.agents) enabledAgents;
    sharedAgents = shared.agentRoles;
  };

  mcp = import ./mcp.nix {
    inherit pkgs mcpOptions;
    enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
    mcpServers = shared.mcp.servers;
  };

  # `--mcp-config` is variadic, so the `=` form is required: the space-separated
  # form swallows the prompt and any subcommand. Shared with the teammate
  # launcher, which repeats it for the agents Claude Code spawns itself.
  mcpFlag = "--mcp-config=${mcp.configFile}";

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      agents
      hostType
      mcpFlag
      modelCatalog
      secretPath
      ;
    inherit (shared) mkProfileSwitch;
  };
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

    proxy = repoLib.proxy.mkProxyOptions "Claude Code";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      homeDir = config.home.homeDirectory;

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      hooks = import ./hooks.nix {
        inherit pkgs lib;
        inherit (shared) mkHooks notify;
      };

      permissions = import ./permissions.nix {
        sharedPermissions = repoLib.llmAssistants.permissions;
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

      # ------------------------------------------------------------------------
      # Status line
      # ------------------------------------------------------------------------
      statusLineConfig = (pkgs.formats.json { }).generate "claude-statusline.json" {
        models = lib.listToAttrs (
          lib.concatLists (
            lib.mapAttrsToList (
              id: model:
              map (name: lib.nameValuePair name model.name) ([ id ] ++ builtins.attrValues model.gatewayId)
            ) modelCatalog.models
          )
        );
      };
      statusLinePackage = pkgs.writers.writeNuBin "statusline-command" {
        makeWrapperArgs = [
          "--add-flag"
          "${statusLineConfig}"
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.ccusage ])
        ];
      } (builtins.readFile ./scripts/statusline-command.nu);
      statusLineScript = "${statusLinePackage}/bin/statusline-command";

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      wrapArgs =
        profiles.wrapArgs
        ++ lib.optionals cfg.plugins.bundle [
          "--set"
          "CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL"
          "1"
        ]
        ++ lib.optionals cfg.proxy.enable [
          "--run"
          (repoLib.proxy.mkProxyScript cfg.proxy)
        ]
        ++ [
          "--add-flags"
          mcpFlag
        ];

      claudeCodeBin = pkgs.symlinkJoin {
        name = "claude-code-${pkgs.claude-code.version}";
        paths = [ pkgs.claude-code ];
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
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        home.sessionVariables = lib.mkIf cfg.plugins.online {
          AGENT_BROWSER_EXECUTABLE_PATH = lib.getExe pkgs.browser-tools.chromium;
        };

        home.packages = profiles.packages;

        programs.claude-code = {
          enable = true;
          package = claudeCodeBin;
          agents = agents.files;

          settings = import ./settings.nix {
            inherit
              lib
              homeDir
              hooks
              modelCatalog
              permissions
              plugins
              ;
            inherit (shared.mcp) timeouts;
            bundlePlugins = cfg.plugins.bundle;
            profileSettings = profiles.settings;
          };
        };

        # ----------------------------------------------------------------------
        # Configuration files
        # ----------------------------------------------------------------------
        home.file = {
          ".claude/CLAUDE.md".text = instructions.claudeCode;
          ".claude/statusline-command" = {
            source = statusLineScript;
            executable = true;
          };
        }
        // profiles.homeFiles;

        # ----------------------------------------------------------------------
        # Activation
        # ----------------------------------------------------------------------
        home.activation.claudeCodeProfile = profiles.activation;
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
