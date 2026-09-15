# ==============================================================================
# OMP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  hostType,
  modelCatalog,
  repoLib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.omp;
  shared = config.lib.llmAssistants;

  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  ompMcpServers = mcpOptions.commonServerNames ++ [ "codex" ];

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      hostType
      modelCatalog
      ;
    inherit (shared) mkProfileSwitch;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.omp = {
    enable = lib.mkEnableOption "OMP";

    auth = profiles.options;

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = ompMcpServers; };

    proxy = repoLib.proxy.mkProxyOptions "OMP";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      json = pkgs.formats.json { };
      yaml = pkgs.formats.yaml { };

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      agents = import ./agents.nix {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
        sharedAgents = shared.agentRoles;
      };

      mcp = import ./mcp.nix {
        inherit lib mcpOptions;
        inherit (shared.mcp) timeouts;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
        mcpServers = shared.mcp.servers;
      };

      models = import ./models.nix {
        inherit
          pkgs
          lib
          corpHosts
          modelCatalog
          secretPath
          ;
        inherit (cfg.auth) enableCorpGateway;
      };

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      wrapArgs =
        lib.optionals cfg.auth.enableCorpGateway [
          "--set"
          "NODE_EXTRA_CA_CERTS"
          (secretPath "llm-assistants/corp-cachain.crt")
        ]
        ++ lib.optionals cfg.proxy.enable [
          "--run"
          (repoLib.proxy.mkProxyScript cfg.proxy)
        ];

      ompBin = pkgs.symlinkJoin {
        name = "omp-${pkgs.omp.version}";
        paths = [ pkgs.omp ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/omp ${lib.escapeShellArgs wrapArgs}
        '';
      };
    in
    lib.mkMerge [
      profiles.config

      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        home.packages = [ ompBin ];

        # ----------------------------------------------------------------------
        # Secrets
        # ----------------------------------------------------------------------
        hakula.secrets.required = models.requiredSecrets;

        # ----------------------------------------------------------------------
        # Configuration files
        # ----------------------------------------------------------------------
        home.file = {
          ".omp/agent/AGENTS.md".text = instructions.omp;
          ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" { inherit (models) providers; };
          ".omp/agent/mcp.json".source = json.generate "omp-mcp.json" { mcpServers = mcp.serversConfig; };
        }
        // agents.homeFiles;
      }
    ]
  );
}
