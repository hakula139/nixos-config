{
  # ============================================================================
  # Home Manager Settings
  # ============================================================================
  home.stateVersion = "25.05";

  # ============================================================================
  # Home Manager Modules
  # ============================================================================
  hakula.claude-code = {
    enable = true;
    proxy.enable = true;
  };
  hakula.cursor.extensions.prune = false;
  hakula.mihomo = {
    enable = true;
    port = 7897;
    controllerPort = 59386;
  };
}
