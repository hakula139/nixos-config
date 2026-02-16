# ==============================================================================
# Direnv (Auto-load .envrc per directory)
# ==============================================================================

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };
}
