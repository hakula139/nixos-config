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

    # The proxy URL points at mihomo.
    hakula.mihomo.enable = true;
    hakula.llm-assistants.proxy.enable = true;
  };
}
