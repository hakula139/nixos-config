# ==============================================================================
# Workstation Baseline Profile
# ==============================================================================
# System-side defaults shared by every "real-Nix" workstation host (macbook,
# wsl). The wsl-non-nixos host runs under system-manager and configures its
# equivalent settings inside the Home Manager tree (see home/modules/wsl).
# ==============================================================================

{ lib, ... }:

{
  # ----------------------------------------------------------------------------
  # Credentials
  # ----------------------------------------------------------------------------
  hakula.cachix.enable = lib.mkDefault true;

  # ----------------------------------------------------------------------------
  # Assistant Tooling
  # ----------------------------------------------------------------------------
  # Personal-flavor MCP set: atlassian and gitlab are disabled (work-flavor
  # leaves can override with `lib.mkForce [ ]`). Proxy is on at the system
  # level; the URL defaults to 127.0.0.1:7897.
  hakula.llm-assistants = {
    enable = lib.mkDefault true;
    mcp.disabledServers = lib.mkDefault [
      "atlassian"
      "gitlab"
    ];
    proxy.enable = lib.mkDefault true;
  };
}
