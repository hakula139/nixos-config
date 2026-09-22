# ==============================================================================
# LLM Assistants
# ==============================================================================

{
  config,
  lib,
  hostType,
  repoLib,
  enableDevToolchains ? false,
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
  ];
  cliAssistantNames = lib.remove "cursor" assistantNames;
  assistants = map (name: config.hakula.${name}) assistantNames;

  # Map each MCP server to the secret it needs at runtime. Servers absent
  # from this attrset do not require any decrypted file.
  mcpServerSecrets = {
    atlassian = [ "llm-assistants/mcp/confluence-pat" ];
    braveSearch = [ "llm-assistants/mcp/brave-api-key" ];
    exa = [ "llm-assistants/mcp/exa-api-key" ];
    github = [ "github/pat" ];
    gitlab = [ "gitlab/pat" ];
  };

  activeServers = lib.unique (
    lib.concatMap (a: if a.enable then mcpOptions.computeEnabledServers a.mcp else [ ]) assistants
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
    ./ccusage
    ./claude-code
    ./codex
    ./ctx7
    ./cursor
    ./omp
    ./opencode
    ./shared
    ./workmux
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = enableDevToolchains;
      description = "Whether to install the LLM assistants and their defaults";
    };

    mcp = {
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable across all LLM assistants";
      };
    };

    proxy = repoLib.proxy.mkProxyOptions "LLM assistants";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      # Clients enabled independently of the bundle still inherit its MCP policy.
      hakula =
        lib.genAttrs assistantNames (_: {
          mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
        })
        // {
          ctx7.enable = lib.mkDefault (lib.any (assistant: assistant.enable) assistants);

          llm-assistants.mcp.disabledServers = lib.mkDefault (
            lib.optionals (hostType == "personal") mcpOptions.corpServerNames
          );

          secrets.required = requiredMcpSecrets;
        };
    }

    (lib.mkIf cfg.enable {
      hakula = lib.genAttrs cliAssistantNames (_: {
        enable = lib.mkDefault true;
        proxy = lib.mkIf cfg.proxy.enable assistantProxy;
      });
    })
  ];
}
