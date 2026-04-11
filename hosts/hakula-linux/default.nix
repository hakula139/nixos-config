# ==============================================================================
# hakula-linux Home Manager Configuration
# ==============================================================================

{
  lib,
  secrets,
  ...
}:

let
  corpDomain = import ../../lib/corp-domain.nix;
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home.stateVersion = "25.05";

  # ----------------------------------------------------------------------------
  # Home Manager Modules
  # ----------------------------------------------------------------------------
  hakula.llm-assistants = {
    enable = true;
    proxy = {
      enable = true;
      noProxy = [
        "localhost"
        "127.0.0.1"
        "10.*"
        ".${corpDomain}"
      ];
    };
  };
  hakula.claude-code.auth.method = "gateway";
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

  # ----------------------------------------------------------------------------
  # Secret Overrides
  # ----------------------------------------------------------------------------
  age.secrets.github-pat.file = lib.mkForce (secrets.secretFile "github-pat-work");
}
