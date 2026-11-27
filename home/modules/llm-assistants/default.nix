# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpHosts,
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
        browser.chromiumPackage = pkgs.browser-tools.chromium;
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
      # Shared agent settings
      # --------------------------------------------------------------------------------------------
      agents = {
        instructions.extraSections = ''
          ## Host Environment

          The configuration repository is nixos-config (`''${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/repository`), whose `AGENTS.md` locates the sources. If a tool or the environment misbehaves, hand the repair to `harness-repair` and continue the main task.

          - **Secrets**: Managed secrets live at `/run/secrets/<service>/<secret>`. Write new values only into their SOPS secret or the untracked file that consumes them.
          - **Browser tools**: Get Playwright / Chromium tools from `nix develop nixos-config#browser`.
        '';

        permissions = {
          ownRepositories = [
            "github.com/hakulab"
            "github.com/hakula139"
            corpHosts.gitlab
          ];

          gateCommands = [
            {
              command = "nixboot";
              reason = "Changes the boot configuration.";
            }
            {
              command = "nixdp";
              reason = "Deploys host configurations.";
            }
            {
              command = "nixroll";
              reason = "Switches system configuration.";
            }
            {
              command = "nixsw";
              reason = "Switches system configuration.";
            }
            {
              command = "nixtest";
              reason = "Switches system configuration.";
            }
          ];
        };

        skills.sources = inputs.flake-catalog.lib.skills;

        # ------------------------------------------------------------------------------------------
        # Primary assistants
        # ------------------------------------------------------------------------------------------
        claude-code = {
          enable = true;
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
