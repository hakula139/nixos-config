# ==============================================================================
# wsl-non-nixos System Manager Configuration
# ==============================================================================

{ config, ... }:

let
  userName = config.hakula.user.name;
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home-manager.users.${userName} = {
    home.stateVersion = "25.05";

    hakula.wsl.enable = true;

    # Light up the local proxy for this host. The shared `hakula.wsl` module
    # leaves both off so the new NixOS-WSL host can start clean; this leaf
    # preserves the previous behaviour for the system-manager-on-Ubuntu host.
    hakula.mihomo.enable = true;
    hakula.llm-assistants.proxy.enable = true;
  };
}
