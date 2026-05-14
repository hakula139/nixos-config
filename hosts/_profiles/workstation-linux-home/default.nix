# ==============================================================================
# Linux workstation Home Manager profile
# ==============================================================================

{
  lib,
  ...
}:

let
  corpDomain = import ../../../lib/corp-domain.nix;
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home.stateVersion = "25.05";

  # ----------------------------------------------------------------------------
  # Home Manager Modules
  # ----------------------------------------------------------------------------
  hakula.claude-code.auth.enableCorpGateway = true;
  hakula.cursor.extensions = {
    enable = lib.mkForce true;
    prune = lib.mkForce false;
  };
  hakula.fonts.windowsSync.enable = true;
  hakula.mihomo = {
    enable = true;
    port = 7897;
    controllerPort = 59386;
  };

  # ----------------------------------------------------------------------------
  # SSH Configuration
  # ----------------------------------------------------------------------------
  programs.ssh.matchBlocks."gitlab-public.${corpDomain}" = {
    host = "gitlab-public.${corpDomain}";
    hostname = "gitlab-public.${corpDomain}";
    user = "git";
    port = 8022;
  };
}
