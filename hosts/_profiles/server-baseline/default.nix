{ lib, ... }:

{
  # ============================================================================
  # Distributed Builds
  # ============================================================================
  hakula.builders.enable = true;

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.cachix.enable = true;
  hakula.claude-code.enable = lib.mkDefault true;
  hakula.mcp.enable = true;

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.netdata.enable = true;
  hakula.services.nginx.enable = true;
  hakula.services.openssh = {
    enable = true;
    ports = [ 35060 ];
  };
  hakula.services.xray = {
    enable = true;
    ws.enable = true;
  };

  # ============================================================================
  # Home Manager Modules
  # ============================================================================
  home-manager.users.hakula.hakula.claude-code.enable = lib.mkDefault true;
  home-manager.users.hakula.hakula.codex.enable = lib.mkDefault true;
}
