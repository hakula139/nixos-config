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

  inherit (shared) agentRoleOptions codexConfigDir instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      shared
      secretPath
      ;
    inherit (cfg.agents) enabledAgents;
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

      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      desktop = import ./desktop.nix {
        homeDir = config.home.homeDirectory;
      };

      hooks = import ./hooks {
        inherit pkgs lib shared;
        inherit (cfg.auth) enableCorpGateway;
      };

      permissions = import ./permissions.nix {
        inherit lib shared;
      };

      mcp = import ./mcp.nix {
        inherit lib mcpOptions shared;
        inherit (permissions) mcpApprovals;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
      };

      plugins = import ./plugins.nix {
        inherit pkgs lib;
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
            ;
        })
        // profiles.settings
        // plugins.settings
      ) (lib.optionalAttrs pkgs.stdenv.isDarwin desktop);

      activateConfig = repoLib.mkNuCommand {
        inherit pkgs;
        name = "activate-codex-config";
        script = ./scripts/activate-config.nu;
        runtimeInputs = [ pkgs.coreutils ];

        config = {
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
      };

      stopStaleDaemon = repoLib.mkNuCommand {
        inherit pkgs;
        name = "stop-stale-codex-daemon";
        script = ./scripts/stop-stale-daemon.nu;
        runtimeInputs = [ codexBin ];
        flags.package = pkgs.codex;
      };
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
            # Separate from default.rules, which Codex rewrites on TUI allowlisting.
            target = "${codexConfigDir}/rules/nixos-config.rules";
            text = permissions.rules;
          };
        };

        xdg.dataFile = hooks.dataFiles;

        # ------------------------------------------------------------------------------------------
        # Activation
        # ------------------------------------------------------------------------------------------
        home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${lib.getExe activateConfig}
        '';

        home.activation.codexDaemon = lib.hm.dag.entryAfter [ "codexAuthProfile" ] ''
          run ${lib.getExe stopStaleDaemon}
        '';
      }
    ]
  );
}
