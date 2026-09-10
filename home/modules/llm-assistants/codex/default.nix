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
  repoLib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.codex;
  shared = config.lib.llmAssistants;

  inherit (shared) instructions agentRoleOptions;
  inherit (repoLib.llmAssistants) mcpOptions;
  codexPkg = pkgs.codex;

  codexMcpServers = mcpOptions.commonServerNames ++ [ "context7" ];
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
      codexPkg
      corpHosts
      hostType
      secretPath
      ;
    inherit (shared) mkProfileSwitch;
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

    mcp = mcpOptions.mkMcpOptions { names = codexMcpServers; };

    proxy = repoLib.proxy.mkProxyOptions "Codex";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      json = pkgs.formats.json { };

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      inherit (shared) notify;

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

      agents = import ./agents.nix {
        inherit pkgs lib;
        inherit (cfg.agents) enabledAgents;
        sharedAgents = shared.agentRoles;
      };

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      proxyScript = pkgs.writeShellScript "codex-proxy-env" (repoLib.proxy.mkProxyScript cfg.proxy);

      # Home Manager uses the version in the name to select the config layout.
      codexBin = pkgs.symlinkJoin {
        name = "codex-${codexPkg.version}";
        paths = [ codexPkg ];
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
            agents
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
        # Mutable config
        # ----------------------------------------------------------------------
        home.activation.codexSkills = skills.activation;

        home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${activateConfig}
        '';

        home.file = skills.homeFile // {
          codexRules = {
            target = codexRulesTarget;
            text = repoLib.llmAssistants.permissions.codexRules + "\n";
          };
        };
      }
    ]
  );
}
