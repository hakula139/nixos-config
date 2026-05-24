# ==============================================================================
# LLM Assistants
# ==============================================================================

{
  config,
  lib,
  hostType,
  llmAssistantLib,
  proxyLib,
  ...
}:

assert lib.assertOneOf "hostType" hostType [
  "personal"
  "work"
];

let
  cfg = config.hakula.llm-assistants;
  mcpSecrets = import ./shared/mcp/secrets.nix;

  # Map each MCP server to the secret it needs at runtime. Servers absent
  # from this attrset (codex, deepwiki, fetcher, filesystem, git) don't
  # require any decrypted file.
  mcpServerSecrets = {
    atlassian = [ "confluence-pat" ];
    braveSearch = [ "brave-api-key" ];
    context7 = [ "context7-api-key" ];
    github = [ "github-pat" ];
    gitlab = [ "gitlab-pat" ];
  };

  inherit (llmAssistantLib) mcpOptions;

  assistants = with config.hakula; [
    claude-code
    codex
    cursor
    opencode
  ];

  activeServers = lib.unique (
    lib.concatMap (
      a:
      if (a.enable or false) then
        lib.subtractLists (a.mcp.disabledServers or [ ]) (a.mcp.enabledServers or [ ])
      else
        [ ]
    ) assistants
  );

  requiredMcpSecretKeys = lib.unique (lib.concatMap (s: mcpServerSecrets.${s} or [ ]) activeServers);

  requiredMcpSecrets = lib.getAttrs requiredMcpSecretKeys mcpSecrets;

  anyAssistantEnabled =
    cfg.enable
    || config.hakula.claude-code.enable
    || config.hakula.codex.enable
    || config.hakula.cursor.enable
    || config.hakula.opencode.enable;

  assistantProxy = {
    enable = lib.mkDefault true;
    url = lib.mkDefault cfg.proxy.url;
    secretUrlFile = lib.mkDefault cfg.proxy.secretUrlFile;
    noProxy = lib.mkDefault cfg.proxy.noProxy;
  };
in
{
  imports = [
    ./claude-code
    ./codex
    ./cursor
    ./opencode
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants = {
    enable = lib.mkEnableOption "LLM assistants defaults";

    mcp = {
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable across all LLM assistants";
      };
    };

    proxy = proxyLib.mkProxyOptions "LLM assistants";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      hakula.llm-assistants.mcp.disabledServers = lib.mkDefault (
        lib.optionals (hostType == "personal") mcpOptions.corpServerNames
        ++ lib.optionals (!config.hakula.codex.enable) [ "codex" ]
      );
    }

    (lib.mkIf anyAssistantEnabled {
      hakula.secrets.required = requiredMcpSecrets;
    })

    (lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          hakula.claude-code = {
            enable = lib.mkDefault true;
            mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
          };

          hakula.codex = {
            enable = lib.mkDefault true;
            mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
          };

          hakula.cursor = {
            mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
          };

          hakula.opencode = {
            enable = lib.mkDefault true;
            mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
          };
        }

        (lib.mkIf cfg.proxy.enable {
          hakula.claude-code.proxy = assistantProxy;
          hakula.codex.proxy = assistantProxy;
          hakula.opencode.proxy = assistantProxy;
        })
      ]
    ))
  ];
}
