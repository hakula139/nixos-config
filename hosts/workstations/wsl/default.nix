# ==============================================================================
# wsl NixOS-WSL Configuration
# ==============================================================================

{
  config,
  lib,
  keys,
  repo,
  hostName,
  ...
}:

{
  imports = [
    repo.profiles.platform.wsl
    repo.profiles.role.workstation
  ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    inherit hostName;
  };

  # ----------------------------------------------------------------------------
  # Access (SSH)
  # ----------------------------------------------------------------------------
  hakula.access.ssh.authorizedKeys = with keys.workstations; [
    hakula-work
  ];

  # ----------------------------------------------------------------------------
  # Assistant Tooling (work flavor)
  # ----------------------------------------------------------------------------
  # Re-enable atlassian + gitlab MCPs that the workstation profile disables
  # for personal hosts.
  hakula.llm-assistants.mcp.disabledServers = lib.mkForce [ ];

  # Mihomo is not configured on this host yet.
  hakula.llm-assistants.proxy.enable = lib.mkForce false;

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  hakula.services.tailscale.enable = true;

  # ----------------------------------------------------------------------------
  # Home Manager Overrides
  # ----------------------------------------------------------------------------
  home-manager.users.${config.hakula.user.name} = {
    hakula.wsl.enable = true;
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
