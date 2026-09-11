# ==============================================================================
# ACPX - ACP Client
# ==============================================================================

{
  pkgs,
  lib,
}:

pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "acpx";
  version = "0.15.1";

  src = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = "acpx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EMr/7/JcEvoULwLYjGR0iy0aYyfnOTnwAxijZXxQnFc=";
  };

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit (pkgs) pnpm;
    fetcherVersion = 4;
    hash = "sha256-z2pqCgG3lPUawQA1x/VkaouQZ4dTlhx17SRVXYF3R7A=";
  };

  nativeBuildInputs = [
    # tsdown excludes Node 25 from its supported versions.
    pkgs.nodejs_24
    pkgs.pnpm
    pkgs.pnpmConfigHook
    pkgs.pnpmBuildHook
    pkgs.makeBinaryWrapper
  ];

  installPhase = ''
    runHook preInstall

    CI=true pnpm prune --prod --ignore-scripts

    mkdir -p "$out/lib/acpx"
    cp -r dist node_modules package.json skills "$out/lib/acpx"

    # Built-in adapters need npx. The resolved node binary lives in nodejs-slim,
    # so acpx cannot find npm beside process.execPath.
    makeWrapper ${lib.getExe pkgs.nodejs_24} "$out/bin/acpx" \
      --add-flags "$out/lib/acpx/dist/cli.js" \
      --suffix PATH : "${lib.makeBinPath [ pkgs.nodejs_24 ]}"

    runHook postInstall
  '';

  meta = {
    description = "Headless CLI client for the Agent Client Protocol";
    homepage = "https://github.com/openclaw/acpx";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "acpx";
  };
})
