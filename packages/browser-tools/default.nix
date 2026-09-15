# ==============================================================================
# Shared Browser Tools
# ==============================================================================

{
  pkgs,
  lib,
}:

let
  inherit (driver) browsers;
  driver = pkgs.playwright-driver;
  chromium = pkgs.callPackage ./chromium.nix { };
in
pkgs.runCommand "browser-tools"
  {
    nativeBuildInputs = [
      pkgs.makeBinaryWrapper
    ];
    passthru = { inherit driver browsers chromium; };
    meta = {
      description = "Playwright CLI and its matching browsers";
      platforms = lib.platforms.unix;
      mainProgram = "playwright";
    };
  }
  ''
    mkdir -p "$out/bin" "$out/lib/node_modules"
    ln -s ${driver} "$out/lib/node_modules/playwright"
    ln -s ${lib.getExe chromium} "$out/bin/chromium"
    makeWrapper ${lib.getExe pkgs.nodejs_24} "$out/bin/playwright" \
      --add-flags ${driver}/cli.js \
      --set PLAYWRIGHT_BROWSERS_PATH ${browsers}
  ''
