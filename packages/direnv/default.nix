# ==================================================================================================
# Direnv
# ==================================================================================================

{
  pkgs,
  direnv,
}:

(direnv.override { bash = pkgs.unstable.bash; }).overrideAttrs (old: {
  # Nix's RewritingSink can corrupt ld-adhoc-signed Mach-O page hashes when sibling outputs
  # (fish-doc) are present, so the kernel SIGKILLs fish during checks (NixOS/nixpkgs#507531).
  doCheck = old.doCheck or true && !pkgs.stdenv.isDarwin;
})
