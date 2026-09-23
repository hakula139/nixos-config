# ==============================================================================
# OMP Configuration
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
  cfg = config.hakula.omp;
  shared = config.lib.llmAssistants;

  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      hostType
      secretPath
      ;
    inherit (shared) profileDefinitions mkProfileSwitch;
    sharedAgents = shared.agentRoles;
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

    mcp = mcpOptions.mkMcpOptions { names = mcpOptions.commonServerNames; };

    proxy = repoLib.proxy.mkProxyOptions "OMP";
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
      agents = import ./agents.nix {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
        sharedAgents = shared.agentRoles;
      };

      extensions = import ./extensions.nix { inherit pkgs; };

      mcp = import ./mcp.nix {
        inherit lib mcpOptions;
        inherit (shared.mcp) timeouts;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
        mcpServers = shared.mcp.servers;
      };

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      wrapArgs = [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [
          pkgs.bun
          pkgs.poppler-utils
        ])
      ]
      ++ lib.optionals cfg.proxy.enable [
        "--run"
        (repoLib.proxy.mkProxyScript cfg.proxy)
      ];

      ompBin = repoLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = pkgs.omp;
        name = "omp-${pkgs.omp.version}";
        bin = "omp";
        envVars = profiles.envVars // {
          PUPPETEER_EXECUTABLE_PATH = lib.getExe' pkgs.browser-tools "chromium";
        };
        envFiles = {
          EXA_API_KEY = secretPath "llm-assistants/mcp/exa-api-key";
          TELEGRAM_BOT_TOKEN = secretPath "llm-assistants/telegram-bot-token";
        };
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
        hakula.secrets.required = {
          inherit (shared.mcpSecrets) "llm-assistants/mcp/exa-api-key";
          "llm-assistants/telegram-bot-token" = { };
        };

        # ----------------------------------------------------------------------
        # Configuration files
        # ----------------------------------------------------------------------
        home.file = {
          ".omp/agent/AGENTS.md".text = instructions.omp;
          ".omp/agent/WATCHDOG.md".text = builtins.readFile ./watchdog.md;
          ".omp/agent/extensions/omp-telegram".source = extensions.telegram;
          ".omp/agent/mcp.json".source = json.generate "omp-mcp.json" { mcpServers = mcp.serversConfig; };
        }
        // agents.homeFiles;
      }
    ]
  );
}
