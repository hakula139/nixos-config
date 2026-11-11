# ==================================================================================================
# WakaTime CLI
# ==================================================================================================

{
  pkgs,
}:

(pkgs.unstable.wakatime-cli.override { buildGoModule = pkgs.unstable.buildGoLatestModule; })
.overrideAttrs
  (old: {
    version = "2.28.4";
    src = old.src.override { hash = "sha256-HkLeRuhIcOnX7ZW3YwYYPQH9Rujb60UjczztNurLS3I="; };
    patches = (old.patches or [ ]) ++ [
      ./cursor-incremental-query.patch
    ];

    vendorHash = "sha256-ElSlITp0zD77nn2afNeAn/Dn17je+hyKD+mCLevBZGE=";
  })
