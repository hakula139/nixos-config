# ==================================================================================================
# Netdata
# ==================================================================================================

{
  pkgs,
}:

pkgs.unstable.netdata.overrideAttrs (old: {
  version = "2.12.2";
  src = old.src.override {
    hash = "sha256-+HsS8x4og3FpQEyn+YBZRYjVNYNTn0PkhOStrsbhWP8=";
  };
})
