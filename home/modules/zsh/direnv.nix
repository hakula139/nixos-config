{
  config,
  lib,
  ...
}:

# ==============================================================================
# Direnv (Auto-load .envrc per directory)
# ==============================================================================

let
  cfg = config.hakula.zsh;
in
{
  programs.direnv = lib.mkIf cfg.direnv.enable {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };
}
