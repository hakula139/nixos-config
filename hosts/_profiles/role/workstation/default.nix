# ==============================================================================
# Workstation Baseline Profile
# ==============================================================================
# System-side defaults shared by every "real-Nix" workstation host (macbook,
# wsl). The wsl-non-nixos host runs under system-manager and configures its
# equivalent settings inside the Home Manager tree (see home/modules/wsl).
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
