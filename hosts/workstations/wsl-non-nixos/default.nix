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

    # Mihomo + the local proxy are paired here: the proxy URL defaults to
    # mihomo at 127.0.0.1:7897, so flipping `proxy.enable` without
    # `mihomo.enable` would dial a dead port.
    hakula.mihomo.enable = true;
    hakula.llm-assistants.proxy.enable = true;
  };
}
