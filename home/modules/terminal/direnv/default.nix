# ==============================================================================
# Direnv (Auto-load .envrc per directory)
# ==============================================================================

{ pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    # Skip checkPhase on Darwin: Nix's RewritingSink corrupts ld-adhoc-signed
    # Mach-O page hashes when sibling outputs (fish-doc) are present, so the
    # kernel SIGKILLs fish mid-test. Drop once NixOS/nix#15638 lands.
    package = pkgs.direnv.overrideAttrs (old: {
      doCheck = old.doCheck or true && !pkgs.stdenv.isDarwin;
    });
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };
}
