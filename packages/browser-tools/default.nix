# ==================================================================================================
# Shared Browser Tools
# ==================================================================================================

{
  pkgs,
  lib,
}:

let
  inherit (driver) browsers;

  # Chrome DevTools MCP runs its latest npm release, which supports only current stable Chrome or
  # newer, while a stable nixpkgs branch freezes Playwright's Chromium for the release's lifetime.
  driver = pkgs.unstable.playwright-driver;
  chromium = pkgs.callPackage ./chromium.nix { inherit driver; };
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
      --set PLAYWRIGHT_BROWSERS_PATH ${browsers} \
      --add-flags ${driver}/cli.js
  ''
