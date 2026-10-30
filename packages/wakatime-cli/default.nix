# ==================================================================================================
# WakaTime CLI
# ==================================================================================================

{
  pkgs,
}:

(pkgs.unstable.wakatime-cli.override { buildGoModule = pkgs.unstable.buildGoLatestModule; })
.overrideAttrs
  (old: {
    version = "2.28.0";
    src = old.src.override { hash = "sha256-GWZLCL+u4tQQ0k5cQaYOPc/pZbjfrP73/SEooNusrRc="; };
    patches = (old.patches or [ ]) ++ [
      ./cursor-incremental-query.patch
    ];

    vendorHash = "sha256-ElSlITp0zD77nn2afNeAn/Dn17je+hyKD+mCLevBZGE=";
  })
