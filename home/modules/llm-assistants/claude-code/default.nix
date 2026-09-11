# ==============================================================================
# Claude Code Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  hostType,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  cfg = config.hakula.claude-code;
  shared = config.lib.llmAssistants;
  homeDir = config.home.homeDirectory;

  inherit (shared) instructions agentRoleOptions;
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
      mcpFlag
      secretPath
      ;
    inherit (shared) mkProfileSwitch;
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

    proxy = repoLib.proxy.mkProxyOptions "Claude Code";
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
        sharedPermissions = repoLib.llmAssistants.permissions;
      };

      hooks = import ./hooks.nix {
        inherit pkgs lib;
        inherit (shared) mkHooks notify;
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
        inherit (instructions) commentGate;
        inherit (cfg.agents) enabledAgents;
        sharedAgents = shared.agentRoles;
      };

      # ------------------------------------------------------------------------
      # Status line
      # ------------------------------------------------------------------------
      statusLinePackage = pkgs.writers.writeNuBin "statusline-command" {
        makeWrapperArgs = [
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
      claudeCodePkg = pkgs.claude-code;

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
        home.sessionVariables = lib.mkIf cfg.plugins.online {
          AGENT_BROWSER_EXECUTABLE_PATH = lib.getExe' pkgs.browser-tools "chromium";
        };

        home.file = {
          ".claude/CLAUDE.md".text = instructions.claudeCode;
          ".claude/statusline-command" = {
            source = statusLineScript;
            executable = true;
          };
        }
        // profiles.homeFiles;

        home.packages = profiles.packages ++ [ pkgs.ccusage ];
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
            inherit (shared.mcp) timeouts;
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
