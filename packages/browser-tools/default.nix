# ==============================================================================
# Shared Browser Tools
# ==============================================================================

{
  pkgs,
  lib,
}:

let
  driver = pkgs.playwright-driver;
  browsers = driver.selectBrowsers {
    withFirefox = false;
    withWebkit = false;
  };
in
pkgs.runCommand "browser-tools"
  {
    nativeBuildInputs = [
      pkgs.nodejs_24
      pkgs.makeWrapper
    ];
    PLAYWRIGHT_BROWSERS_PATH = browsers;
    passthru = { inherit driver browsers; };
    meta = {
      description = "Playwright CLI and its matching Chromium browsers";
      platforms = lib.platforms.unix;
      mainProgram = "playwright";
    };
  }
  ''
    mkdir -p "$out/bin" "$out/lib/node_modules"
    ln -s ${driver} "$out/lib/node_modules/playwright"
    browserPath=$(node -p 'require("${driver}").chromium.executablePath()')
    makeWrapper "$browserPath" "$out/bin/chromium"
    makeWrapper ${lib.getExe pkgs.nodejs_24} "$out/bin/playwright" \
      --add-flags ${driver}/cli.js \
      --set PLAYWRIGHT_BROWSERS_PATH ${browsers}
  ''
