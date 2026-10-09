# ==================================================================================================
# WakaTime CLI
# ==================================================================================================

{
  pkgs,
}:

(pkgs.unstable.wakatime-cli.override { buildGoModule = pkgs.unstable.buildGoLatestModule; })
.overrideAttrs
  (old: {
    version = "2.26.15";
    src = old.src.override { hash = "sha256-/LiRiG7d2A5UeNC1+zp72/ZNPMGNn4Hhl7XyxRH2hTI="; };
    patches = (old.patches or [ ]) ++ [
      ./cursor-incremental-query.patch
    ];
    vendorHash = "sha256-MpE3Q/YK7SliqxF4aM1fyUWe70SNI7qlex7mUQk1W6g=";
  })
