# ==================================================================================================
# Direnv (Auto-load .envrc per directory)
# ==================================================================================================

{
  pkgs,
  lib,
  ...
}:

{
  programs.direnv = {
    enable = true;
    package =
      (pkgs.direnv.override (
        lib.optionalAttrs pkgs.stdenv.isDarwin {
          bash = pkgs.unstable.bash;
        }
      )).overrideAttrs
        (old: {
          # Skip checkPhase on Darwin: Nix's RewritingSink corrupts ld-adhoc-signed Mach-O page hashes
          # when sibling outputs (fish-doc) are present, so the kernel SIGKILLs fish mid-test. Drop once
          # NixOS/nix#15638 lands.
          doCheck = old.doCheck or true && !pkgs.stdenv.isDarwin;
        });

    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };
}
