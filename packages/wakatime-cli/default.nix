# ==================================================================================================
# WakaTime CLI
# ==================================================================================================

{
  pkgs,
}:

let
  go = pkgs.unstable.buildPackages.go_1_27.overrideAttrs (
    finalAttrs: _: {
      version = "1.27.4";
      src = pkgs.unstable.fetchurl {
        url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
        hash = "sha256-c8+4VxrsDAEXdofbhxY9Rqog6XeWcncokaoXZU2aYJk=";
      };
    }
  );

  buildGoModule = pkgs.unstable.buildGoLatestModule.override { inherit go; };
in
(pkgs.unstable.wakatime-cli.override { inherit buildGoModule; }).overrideAttrs (_: {
  version = "2.28.4-unstable-2026-11-14";
  src = pkgs.fetchFromGitHub {
    owner = "hakula139";
    repo = "wakatime-cli";
    rev = "16b395769f068405f952c22e996ad774582b0671";
    hash = "sha256-BJBE+x62ZRxqc7srbqDxwZjEtW7LQWezRxE9dDyRP9s=";
  };

  vendorHash = "sha256-Tz0MvNU9iuIMNzWsy/R8+onBb2iZBCAem2XyAH8pVP4=";
})
