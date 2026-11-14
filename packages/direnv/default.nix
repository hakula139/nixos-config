# ==================================================================================================
# Direnv
# ==================================================================================================

{
  pkgs,
  direnv,
}:

(direnv.override { bash = pkgs.unstable.bash; }).overrideAttrs (old: {
  # Skip checkPhase on Darwin: Nix's RewritingSink corrupts ld-adhoc-signed Mach-O page hashes
  # when sibling outputs (fish-doc) are present, so the kernel SIGKILLs fish mid-test.
  doCheck = old.doCheck or true && !pkgs.stdenv.isDarwin;
})
