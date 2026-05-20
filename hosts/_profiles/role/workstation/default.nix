# ==============================================================================
# Workstation Baseline Profile
# ==============================================================================

{ lib, ... }:

{
  hakula.cachix.enable = lib.mkDefault true;

  # Personal-flavor MCP set by default. Work-flavor leaves can override
  # with `lib.mkForce [ ]`.
  hakula.llm-assistants = {
    enable = lib.mkDefault true;
    mcp.disabledServers = lib.mkDefault [
      "atlassian"
      "gitlab"
    ];
    proxy.enable = lib.mkDefault true;
  };
}
