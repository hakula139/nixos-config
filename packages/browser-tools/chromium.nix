# ==================================================================================================
# Playwright Chromium
# ==================================================================================================

{
  pkgs,
  lib,
  driver,
}:

let
  browsers = driver.browsers-chromium;
in
pkgs.runCommand "playwright-chromium"
  {
    nativeBuildInputs = [
      pkgs.nodejs_26
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
