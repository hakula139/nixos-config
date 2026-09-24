# ==============================================================================
# Codex Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  repoLib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.codex;
  shared = config.lib.llmAssistants;

  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  corpGateway = shared.profileDefinitions.providers.corp-gateway;

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
      hostType
      secretPath
      ;
    inherit (shared) profileDefinitions mkProfileSwitch;
    inherit (cfg.agents) enabledAgents;
    sharedAgents = shared.agentRoles;
    configDir = codexConfigDir;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
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

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      inherit (shared) notify;

      json = pkgs.formats.json { };

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      hooks = import ./hooks.nix {
        inherit pkgs lib;
        inherit (shared) mkHooks;
        gateway = lib.optionalAttrs cfg.auth.enableCorpGateway {
          inherit (corpGateway) baseUrl;
          tokenFile = secretPath corpGateway.tokenSecret;
          caFile = secretPath corpGateway.caSecret;
        };
      };

      mcp = import ./mcp.nix {
        inherit lib mcpOptions;
        inherit (shared.mcp) timeouts;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
        mcpServers = shared.mcp.servers;
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

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      # Home Manager uses the version in the name to select the config layout.
      codexBin = repoLib.wrapPackage {
        inherit pkgs;
        inherit (profiles) envVars;
        pkg = pkgs.codex;
        name = "codex-${pkgs.codex.version}";
        bin = "codex";
        wrapArgs = lib.optionals cfg.proxy.enable [
          "--run"
          (repoLib.proxy.mkProxyScript cfg.proxy)
        ];
      };

      # ------------------------------------------------------------------------
      # Config activation
      # ------------------------------------------------------------------------
      codexSettings =
        (import ./settings.nix {
          inherit
            hooks
            mcp
            notify
            skills
            ;
        })
        // profiles.settings;

      activationConfig = json.generate "codex-config-activation.json" {
        configDir = codexConfigDir;
        activeProfile = "${profiles.stateDir}/active-profile";
        settings = codexSettings;
      };

      activateConfig = pkgs.writers.writeNu "activate-codex-config" {
        makeWrapperArgs = [
          "--add-flag"
          "${activationConfig}"
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.coreutils ])
        ];
      } (builtins.readFile ./scripts/activate-config.nu);

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
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        programs.codex = {
          enable = true;
          package = codexBin;
          context = instructions.codex;
        };

        # ----------------------------------------------------------------------
        # Configuration files
        # ----------------------------------------------------------------------
        home.file = {
          codexRules = {
            target = codexRulesTarget;
            text = repoLib.llmAssistants.permissions.codexRules;
          };
        };

        # ----------------------------------------------------------------------
        # Activation
        # ----------------------------------------------------------------------
        home.activation.codexSkills = skills.activation;

        home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${activateConfig}
        '';
      }
    ]
  );
}
