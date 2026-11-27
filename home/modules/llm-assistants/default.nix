# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  config,
  lib,
  inputs,
  repoLib,
  enableDevToolchains,
  hostType,
  secretPath,
  ...
}:

assert lib.assertOneOf "hostType" hostType [
  "personal"
  "work"
];

let
  cfg = config.hakula.llm-assistants;

  corpServerNames = [
    "atlassian"
    "bifrost"
    "gitlab"
    "mirrorCatalog"
  ];
in
{
  imports = [
    inputs.agents-nix.homeModules.default

    ./caldav.nix
    ./mcp.nix
    ./permissions.nix
    ./providers
    ./t3code.nix
  ];

  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.llm-assistants = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = enableDevToolchains;
      description = "Whether to install the LLM assistants and their defaults";
    };

    auth.enableCorpGateway = lib.mkOption {
      type = lib.types.bool;
      default = hostType == "work";
      description = "Include corporate gateway profiles and provision their credentials";
    };

    mcp = {
      disabledServers = inputs.agents-nix.lib.mcp.mkDisabledServersOption {
        description = "MCP servers to disable across all LLM assistants";
      };
    };

    proxy = repoLib.proxy.mkProxyOptions "LLM assistants";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      agents = {
        instructions.enable = lib.mkDefault cfg.enable;

        proxy = {
          inherit (cfg.proxy)
            enable
            url
            secretUrlFile
            noProxy
            ;
        };
      };

      hakula.llm-assistants.mcp.disabledServers = lib.mkDefault (
        lib.optionals (hostType == "personal") corpServerNames
      );
    }

    (lib.mkIf cfg.enable {
      # --------------------------------------------------------------------------------------------
      # Agents
      # --------------------------------------------------------------------------------------------
      agents = {
        # ------------------------------------------------------------------------------------------
        # Shared settings
        # ------------------------------------------------------------------------------------------
        instructions.extraSections = builtins.readFile ./host-environment.md;

        skills.sources = inputs.flake-catalog.lib.skills;

        # ------------------------------------------------------------------------------------------
        # Primary assistants
        # ------------------------------------------------------------------------------------------
        claude-code = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
          hooks.worktree.workmuxPackage = config.agents.workmux.package;
          plugins.lspPlugins = enableDevToolchains;
        };

        codex.enable = true;

        omp = {
          enable = true;
          extensions.telegram = {
            enable = true;
            botTokenFile = secretPath "llm-assistants/telegram-bot-token";
          };
          extraEnvFiles.EXA_API_KEY = secretPath "llm-assistants/mcp/exa-api-key";
        };

        oxide-code.enable = true;

        # ------------------------------------------------------------------------------------------
        # Peripheral tools
        # ------------------------------------------------------------------------------------------
        acp.enable = true;

        activity-report = {
          enable = true;
          labels = {
            default = [ hostType ];
            projects.nixos-config = lib.mkDefault [ "personal" ];
          };
        };

        agent-project-move.enable = true;

        ccusage.enable = true;

        ctx7 = {
          enable = true;
          apiKeyFile = secretPath "llm-assistants/mcp/context7-api-key";
        };

        workmux.enable = true;
      };

      # --------------------------------------------------------------------------------------------
      # Secrets
      # --------------------------------------------------------------------------------------------
      hakula.secrets.required = {
        "llm-assistants/mcp/context7-api-key" = { };
        "llm-assistants/mcp/exa-api-key" = { };
        "llm-assistants/telegram-bot-token" = { };
      };
    })
  ];
}
