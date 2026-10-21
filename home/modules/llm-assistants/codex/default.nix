# ==================================================================================================
# Codex Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.codex;
  shared = config.lib.llmAssistants;

  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  codexConfigDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      secretPath
      ;
    inherit (cfg.agents) enabledAgents;
    inherit (shared) profileDefinitions mkProfileSwitch;
    sharedAgents = shared.agentRoles;
    configDir = codexConfigDir;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI";

    auth = profiles.options;

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = mcpOptions.commonServerNames; };

    proxy = repoLib.proxy.mkProxyOptions "Codex";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      inherit (shared) notify;

      json = pkgs.formats.json { };

      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      desktop = import ./desktop.nix {
        homeDir = config.home.homeDirectory;
      };

      hooks = import ./hooks {
        inherit pkgs lib;
        inherit (shared) mkHooks;
        inherit (cfg.auth) enableCorpGateway;
      };

      permissions = import ./permissions.nix {
        inherit lib;
        policy = repoLib.llmAssistants.permissions;
      };

      mcp = import ./mcp.nix {
        inherit lib mcpOptions;
        inherit (permissions) mcpApprovals;
        inherit (shared.mcp) timeouts;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
        mcpServers = shared.mcp.servers;
      };

      plugins = import ./plugins.nix {
        inherit pkgs lib;
      };

      skills = import ./skills {
        inherit
          config
          pkgs
          lib
          ;
        configDir = codexConfigDir;
        sharedSkills = shared.skills;
      };

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      # Home Manager uses the version in the name to select the config layout.
      codexBin = repoLib.wrapPackage {
        inherit pkgs;
        inherit (profiles) envVars;
        pkg = pkgs.codex;
        name = "codex-${pkgs.codex.version}";
        bin = "codex";
        wrapArgs =
          lib.optionals pkgs.stdenv.isLinux [
            "--suffix"
            "PATH"
            ":"
            (lib.makeBinPath [ pkgs.bubblewrap ])
          ]
          ++ lib.optionals cfg.proxy.enable [
            "--run"
            (repoLib.proxy.mkProxyScript cfg.proxy)
          ];
      };

      # --------------------------------------------------------------------------------------------
      # Config activation
      # --------------------------------------------------------------------------------------------
      codexSettings = lib.recursiveUpdate (
        (import ./settings.nix {
          inherit
            hooks
            mcp
            notify
            permissions
            skills
            ;
        })
        // profiles.settings
        // plugins.settings
      ) (lib.optionalAttrs pkgs.stdenv.isDarwin desktop);

      activationConfig = json.generate "codex-config-activation.json" {
        configDir = codexConfigDir;
        activeProfile = "${profiles.stateDir}/active-profile";
        settings = codexSettings;
        keybindings = lib.optionals pkgs.stdenv.isDarwin [
          {
            command = "hotkeyWindow";
            key = "Command+Shift+Space";
          }
        ];
      };

      activateConfig = pkgs.writers.writeNu "activate-codex-config" {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.coreutils ])

          "--add-flag"
          "${activationConfig}"
        ];
      } (builtins.readFile ./scripts/activate-config.nu);

      stopStaleDaemon = pkgs.writers.writeNu "stop-stale-codex-daemon" {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ codexBin ])

          "--add-flag"
          "${pkgs.codex}"
        ];
      } (builtins.readFile ./scripts/stop-stale-daemon.nu);

      # Separate from default.rules, which Codex rewrites on TUI allowlisting.
      codexRulesTarget =
        if config.home.preferXdgDirectories then
          "${lib.removePrefix "${config.home.homeDirectory}/" config.xdg.configHome}/codex/rules/nixos-config.rules"
        else
          ".codex/rules/nixos-config.rules";
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Program configuration
        # ------------------------------------------------------------------------------------------
        programs.codex = {
          enable = true;
          package = codexBin;
          context = instructions.codex;
        };

        # ------------------------------------------------------------------------------------------
        # Configuration files
        # ------------------------------------------------------------------------------------------
        home.file = {
          codexRules = {
            target = codexRulesTarget;
            text = permissions.rules;
          };
        };

        xdg.dataFile = hooks.dataFiles;

        # ------------------------------------------------------------------------------------------
        # Activation
        # ------------------------------------------------------------------------------------------
        home.activation.codexSkills = skills.activation;

        home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${activateConfig}
        '';

        home.activation.codexDaemon = lib.hm.dag.entryAfter [ "codexAuthProfile" ] ''
          run ${stopStaleDaemon}
        '';
      }
    ]
  );
}
