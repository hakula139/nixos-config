# ==============================================================================
# LLM Assistants
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
  mcpOptions = import ./shared/mcp/options.nix { inherit lib; };
  proxyOptions = import ./shared/proxy.nix { inherit lib; };
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

    proxy = proxyOptions.mkProxyOptions "LLM assistants";
  };

  config = lib.mkIf cfg.enable (
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
        hakula.claude-code.proxy = {
          enable = lib.mkDefault true;
          url = lib.mkDefault cfg.proxy.url;
          noProxy = lib.mkDefault cfg.proxy.noProxy;
        };

        hakula.codex.proxy = {
          enable = lib.mkDefault true;
          url = lib.mkDefault cfg.proxy.url;
          noProxy = lib.mkDefault cfg.proxy.noProxy;
        };

        hakula.opencode.proxy = {
          enable = lib.mkDefault true;
          url = lib.mkDefault cfg.proxy.url;
          noProxy = lib.mkDefault cfg.proxy.noProxy;
        };
      })
    ]
  );
}
