# ==============================================================================
# Claude Code Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
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
      hostType
      secretPath
      mcpFlag
      ;
    inherit (shared) profileDefinitions mkProfileSwitch;
    inherit (cfg.agents) enabledAgents;
    sharedAgents = shared.agentRoles;
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
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = mcpOptions.commonServerNames; };

    plugins.bundle = lib.mkEnableOption "pre-bundled plugins (for air-gapped deployment)";

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
          enableDevToolchains
          ;
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
      statusLineScript = lib.getExe statusLinePackage;

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      wrapArgs =
        profiles.wrapArgs
        ++ lib.optionals cfg.proxy.enable [
          "--run"
          (repoLib.proxy.mkProxyScript cfg.proxy)
        ]
        ++ [
          "--add-flags"
          mcpFlag
        ];

      claudeCodeBin = repoLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = pkgs.claude-code;
        name = "claude-code-${pkgs.claude-code.version}";
        bin = "claude";
        envVars = lib.optionalAttrs cfg.plugins.bundle {
          CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
        };
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
        programs.claude-code = {
          enable = true;
          package = claudeCodeBin;

          settings = import ./settings.nix {
            inherit
              lib
              homeDir
              hooks
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
