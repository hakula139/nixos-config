# ==============================================================================
# WSL Non-NixOS System Manager Configuration
# ==============================================================================

{ config, ... }:

let
  userName = config.hakula.user.name;
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Overrides
  # ----------------------------------------------------------------------------
  home-manager.users.${userName} = {
    hakula.llm-assistants.proxy.enable = true;
    hakula.mihomo.enable = true;
    hakula.wsl.enable = true;

    home.stateVersion = "25.05";
  };
}
