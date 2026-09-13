# ==============================================================================
# Playwright Chromium
# ==============================================================================

{
  pkgs,
  lib,
}:

let
  driver = pkgs.playwright-driver;
  browsers = driver.browsers-chromium;
in
pkgs.runCommand "playwright-chromium"
  {
    nativeBuildInputs = [
      pkgs.nodejs_24
      pkgs.makeBinaryWrapper
    ];
    PLAYWRIGHT_BROWSERS_PATH = browsers;
    meta = {
      description = "Chromium matching the pinned Playwright driver";
      platforms = lib.platforms.unix;
      mainProgram = "chromium";
    };
  }
  ''
    mkdir -p "$out/bin"
    browserPath=$(node -p 'require("${driver}").chromium.executablePath()')
    makeWrapper "$browserPath" "$out/bin/chromium"
  ''
