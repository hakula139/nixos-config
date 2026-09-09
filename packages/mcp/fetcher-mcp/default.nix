# ==============================================================================
# MCP Server – Fetcher
# ==============================================================================

{
  pkgs,
  lib,
}:

pkgs.buildNpmPackage {
  pname = "fetcher-mcp";
  version = "0.3.9";

  src = pkgs.fetchFromGitHub {
    owner = "jae-jae";
    repo = "fetcher-mcp";
    rev = "8754aff66e3d9207502207bf82a493f45f556bb8";
    hash = "sha256-CH9qTU+BS3/zCs9QVIHPqoHdul9qpaha1D+gZzoLteY=";
  };

  npmDepsHash = "sha256-waLaOeDaCsgltLrri0kjjFJPazOE/cY+2F+Yu0i55Cg=";
  npmFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

  postPatch = ''
    # Nix supplies the browser, so an MCP tool must not try to install it at runtime.
    sed -i '/browserInstall/d' src/tools/index.ts
    rm src/tools/browserInstall.ts
    substituteInPlace src/services/browserService.ts \
      --replace-fail "please call the 'browser_install' tool to install the required browser binaries" \
        "rebuild the Nix browser-tools package to restore its browser binaries"
  '';

  postInstall = ''
    packageDir="$out/lib/node_modules/fetcher-mcp"
    rm -r "$packageDir/node_modules/playwright" "$packageDir/node_modules/playwright-core"
    ln -s ${pkgs.browser-tools.driver} "$packageDir/node_modules/playwright"
    ln -s ${pkgs.browser-tools.driver} "$packageDir/node_modules/playwright-core"
    wrapProgram "$out/bin/fetcher-mcp" \
      --set PLAYWRIGHT_BROWSERS_PATH ${pkgs.browser-tools.browsers}
  '';

  meta = {
    description = "MCP server for fetching web content with Playwright";
    homepage = "https://github.com/jae-jae/fetcher-mcp";
    license = lib.licenses.isc;
    platforms = lib.platforms.unix;
    mainProgram = "fetcher-mcp";
  };
}
