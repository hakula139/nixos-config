# ==================================================================================================
# OMP Configuration
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
  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  cfg = config.hakula.omp;
  shared = config.lib.llmAssistants;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      shared
      secretPath
      ;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.omp = {
    auth = profiles.options;

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = mcpOptions.commonServerNames; };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf config.hakula.llm-assistants.enable (
    let
      json = pkgs.formats.json { };
      yaml = pkgs.formats.yaml { };

      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      agents = import ./agents.nix {
        inherit lib shared;
        inherit (cfg.agents) enabledAgents;
      };

      extensions = import ./extensions.nix {
        inherit pkgs;
      };

      mcp = import ./mcp.nix {
        inherit lib shared mcpOptions;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
      };

      settingsConfigFile = yaml.generate "omp-settings.yml" (
        import ./settings.nix {
          inherit shared;
        }
      );

      permissionConfigFile = yaml.generate "omp-permissions.yml" (
        import ./permissions.nix {
          inherit lib shared;
        }
      );

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs = [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [
          pkgs.bun
          pkgs.poppler-utils
        ])
      ]
      ++ repoLib.proxy.mkProxyWrapArgs config.hakula.llm-assistants.proxy
      ++ [
        "--add-flags"
        "--config ${settingsConfigFile}"

        "--add-flags"
        "--config ${permissionConfigFile}"
      ];

      ompBin = repoLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = pkgs.omp;
        name = "omp-${pkgs.omp.version}";
        bin = "omp";
        envVars = profiles.envVars // {
          PUPPETEER_EXECUTABLE_PATH = lib.getExe pkgs.browser-tools.chromium;
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
        # ------------------------------------------------------------------------------------------
        # Program configuration
        # ------------------------------------------------------------------------------------------
        home.packages = [
          ompBin
        ];

        # ------------------------------------------------------------------------------------------
        # Secrets
        # ------------------------------------------------------------------------------------------
        hakula.secrets.required = {
          "llm-assistants/mcp/exa-api-key" = { };
          "llm-assistants/telegram-bot-token" = { };
        };

        # ------------------------------------------------------------------------------------------
        # Configuration files
        # ------------------------------------------------------------------------------------------
        home.file = {
          ".omp/agent/AGENTS.md".text = instructions;
          ".omp/agent/WATCHDOG.md".text = builtins.readFile ./watchdog.md;
          ".omp/agent/extensions/file-formatter.ts".source = pkgs.replaceVars ./file-formatter.ts {
            inherit (shared) fileFormatter;
          };
          ".omp/agent/extensions/omp-telegram".source = extensions.telegram;
          ".omp/agent/mcp.json".source = json.generate "omp-mcp.json" { mcpServers = mcp.serversConfig; };
        }
        // agents.homeFiles;
      }
    ]
  );
}
