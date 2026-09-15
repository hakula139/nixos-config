# ==============================================================================
# Codex Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpHosts,
  hostType,
  modelCatalog,
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
  codexMcpServers = mcpOptions.commonServerNames ++ [ "context7" ];

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      corpHosts
      hostType
      modelCatalog
      secretPath
      ;
    inherit (shared) mkProfileSwitch;
    inherit (cfg.agents) enabledAgents;
    configDir = codexConfigDir;
    sharedAgents = shared.agentRoles;
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

    mcp = mcpOptions.mkMcpOptions { names = codexMcpServers; };

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
          baseUrl = corpHosts.llmGatewayUrl;
          tokenFile = secretPath "llm-assistants/bifrost-api-key";
          caFile = secretPath "llm-assistants/corp-cachain.crt";
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
          inputs
          ;
        configDir = codexConfigDir;
        sharedSkills = shared.skills;
      };

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      proxyScript = pkgs.writeShellScript "codex-proxy-env" (repoLib.proxy.mkProxyScript cfg.proxy);

      # Home Manager uses the version in the name to select the config layout.
      codexBin = pkgs.symlinkJoin {
        name = "codex-${pkgs.codex.version}";
        paths = [ pkgs.codex ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/codex \
            ${lib.escapeShellArgs profiles.wrapArgs} \
            ${lib.optionalString cfg.proxy.enable "--run ${lib.escapeShellArg "source ${proxyScript}"}"}
        '';
      };

      # ------------------------------------------------------------------------
      # Config activation
      # ------------------------------------------------------------------------
      codexSettings =
        (import ./settings.nix {
          inherit
            hooks
            mcp
            modelCatalog
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
        home.file = skills.homeFile // {
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
          ${activateConfig}
        '';
      }
    ]
  );
}
