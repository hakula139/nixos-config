# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  config,
  options,
  lib,
  repoLib,
  enableDevToolchains,
  hostType,
  ...
}:

assert lib.assertOneOf "hostType" hostType [
  "personal"
  "work"
];

let
  inherit (repoLib.llmAssistants) mcpOptions;

  cfg = config.hakula.llm-assistants;
  corpGateway = config.lib.llmAssistants.profileDefinitions.providers.corp-gateway;

  assistantNames = [
    "claude-code"
    "codex"
    "cursor"
    "omp"
    "oxide-code"
    "t3code"
  ];

  mcpAssistantNames = lib.filter (name: options.hakula.${name} ? mcp) assistantNames;

  mcpAssistants = map (name: config.hakula.${name}) (
    lib.filter (name: name != "cursor" || config.hakula.cursor.enable) mcpAssistantNames
  );

  mcpServerSecrets = {
    atlassian = [
      "llm-assistants/mcp/confluence-pat"
    ];

    bifrost = [
      (corpGateway.tokenSecretFor "claude-code")
      corpGateway.caSecret
    ];

    exa = [
      "llm-assistants/mcp/exa-api-key"
    ];

    gitlab = [
      "gitlab/pat"
    ];
  };

  activeServers = lib.unique (
    lib.concatMap (a: mcpOptions.computeEnabledServers a.mcp) mcpAssistants
  );

  requiredMcpSecretKeys = lib.unique (lib.concatMap (s: mcpServerSecrets.${s} or [ ]) activeServers);

  requiredMcpSecrets = lib.genAttrs requiredMcpSecretKeys (_: { });
in
{
  imports = [
    ./acp
    ./activity-report
    ./agent-project-move
    ./caldav.nix
    ./ccusage
    ./claude-code
    ./codex
    ./ctx7
    ./omp
    ./oxide-code
    ./shared
    ./t3code
    ./workmux
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
      disabledServers = mcpOptions.mkDisabledServersOption {
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
      # Keep agents.nix instruction docs disabled until shared and primary assistants cut over.
      agents = {
        instructions.enable = false;

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
        lib.optionals (hostType == "personal") mcpOptions.corpServerNames
      );
    }

    (lib.mkIf cfg.enable {
      hakula = lib.mkMerge [
        (lib.genAttrs mcpAssistantNames (_: {
          mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
        }))

        {
          secrets.required =
            requiredMcpSecrets
            // lib.optionalAttrs cfg.auth.enableCorpGateway {
              "llm-assistants/corp-gateway/portal-token" = { };
            };
        }
      ];
    })
  ];
}
