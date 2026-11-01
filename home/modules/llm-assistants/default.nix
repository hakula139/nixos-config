# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  config,
  lib,
  options,
  hostType,
  repoLib,
  enableDevToolchains ? false,
  isDesktop ? false,
  ...
}:

assert lib.assertOneOf "hostType" hostType [
  "personal"
  "work"
];

let
  inherit (config.lib.llmAssistants) mcpSecrets;
  inherit (repoLib.llmAssistants) mcpOptions;

  cfg = config.hakula.llm-assistants;

  assistantNames = [
    "claude-code"
    "codex"
    "cursor"
    "omp"
    "opencode"
    "oxide-code"
  ];

  cliAssistantNames = lib.remove "cursor" assistantNames;
  mcpAssistantNames = lib.filter (name: options.hakula.${name} ? mcp) assistantNames;

  # Cursor's IDE settings apply to every host, so it acts as an assistant only within the bundle.
  mcpAssistants = map (name: config.hakula.${name}) (
    lib.filter (name: name != "cursor" || cfg.enable) mcpAssistantNames
  );

  # Map each MCP server to the secret it needs at runtime. Servers absent from this attrset do not
  # require any decrypted file.
  mcpServerSecrets = {
    atlassian = [ "llm-assistants/mcp/confluence-pat" ];
    bifrost = [
      "llm-assistants/corp-gateway/claude-code-api-key"
      "llm-assistants/corp-gateway/cachain.crt"
    ];

    braveSearch = [ "llm-assistants/mcp/brave-api-key" ];
    exa = [ "llm-assistants/mcp/exa-api-key" ];
    gitlab = [ "gitlab/pat" ];
  };

  activeServers = lib.unique (
    lib.concatMap (a: lib.optionals a.enable (mcpOptions.computeEnabledServers a.mcp)) mcpAssistants
  );

  requiredMcpSecretKeys = lib.unique (lib.concatMap (s: mcpServerSecrets.${s} or [ ]) activeServers);

  requiredMcpSecrets = lib.getAttrs requiredMcpSecretKeys mcpSecrets;

  assistantProxy = {
    enable = lib.mkDefault true;
    url = lib.mkDefault cfg.proxy.url;
    secretUrlFile = lib.mkDefault cfg.proxy.secretUrlFile;
    noProxy = lib.mkDefault cfg.proxy.noProxy;
  };
in
{
  imports = [
    ./acp
    ./activity-report
    ./ccusage
    ./claude-code
    ./codex
    ./ctx7
    ./cursor
    ./omp
    ./opencode
    ./oxide-code
    ./shared
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
      # Clients enabled apart from the bundle still inherit its MCP policy.
      hakula =
        lib.genAttrs mcpAssistantNames (_: {
          mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
        })
        // {
          llm-assistants.mcp.disabledServers = lib.mkDefault (
            lib.optionals (hostType == "personal") mcpOptions.corpServerNames
          );

          secrets.required = requiredMcpSecrets;
        };
    }

    (lib.mkIf cfg.auth.enableCorpGateway {
      hakula.secrets.required."llm-assistants/corp-gateway/portal-token" = { };
    })

    (lib.mkIf cfg.enable {
      hakula =
        lib.genAttrs cliAssistantNames (_: {
          enable = lib.mkDefault true;
          proxy = lib.mkIf cfg.proxy.enable assistantProxy;
        })
        // lib.genAttrs [ "acp" "ccusage" "ctx7" "workmux" ] (_: {
          enable = lib.mkDefault true;
        })
        // {
          activity-report.enable = lib.mkDefault isDesktop;
        };
    })
  ];
}
