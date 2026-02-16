# ==============================================================================
# Zoxide (Smarter cd command)
# ==============================================================================

{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd"
      "j"
    ];
  };
}
