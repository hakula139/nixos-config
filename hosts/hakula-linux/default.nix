{
  lib,
  secrets,
  ...
}:

{
  # ============================================================================
  # Home Manager Settings
  # ============================================================================
  home.stateVersion = "25.05";

  # ============================================================================
  # Home Manager Modules
  # ============================================================================
  hakula.llm-assistants = {
    enable = true;
    proxy.enable = true;
  };
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

  # ============================================================================
  # Secret Overrides
  # ============================================================================
  age.secrets.github-pat.file = lib.mkForce (secrets.secretFile "github-pat-work");
}
