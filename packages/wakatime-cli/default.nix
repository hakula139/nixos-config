# ==============================================================================
# WakaTime CLI
# ==============================================================================

{
  pkgs,
}:

(pkgs.unstable.wakatime-cli.override { buildGoModule = pkgs.unstable.buildGoLatestModule; })
.overrideAttrs
  (old: {
    version = "2.26.11";
    src = old.src.override { hash = "sha256-3OB2oyObnkbterceYcAokCGZTDPv0SfIjgFoQcUyWPI="; };
    vendorHash = "sha256-MpE3Q/YK7SliqxF4aM1fyUWe70SNI7qlex7mUQk1W6g=";
  })
