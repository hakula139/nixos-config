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

  # The role/workstation profile turns the local proxy on by default
  # (URL = mihomo at 127.0.0.1:7897). Mihomo isn't running on this host
  # yet, so keep the proxy off until subscription secrets are confirmed
  # and the proxy can be enabled as a pair with mihomo.
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
    # Local proxy stays off until mihomo subscription secrets are confirmed.
    # Flip both on as a pair when ready:
    #   hakula.mihomo.enable               = true;
    #   hakula.llm-assistants.proxy.enable = true;
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
