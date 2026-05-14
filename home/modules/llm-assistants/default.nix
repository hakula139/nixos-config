# ==============================================================================
# LLM Assistants
# ==============================================================================

{
  config,
  lib,
  llmAssistantLib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;

  inherit (llmAssistantLib) mcpOptions;
  proxyLib = llmAssistantLib.proxy;

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

  options.hakula.llm-assistants = {
    enable = lib.mkEnableOption "LLM assistants defaults";

    mcp = {
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable across all LLM assistants";
      };
    };

    proxy = proxyLib.mkProxyOptions "LLM assistants";
  };

  config = lib.mkMerge [
    (lib.mkIf anyAssistantEnabled {
      hakula.secrets.required = llmAssistantLib.secretSpecs.mcp;
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
