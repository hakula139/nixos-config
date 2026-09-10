# ==============================================================================
# ACPX - ACP Client
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  # The upstream build tool supports Node 22 and 24, but rejects Node 25.
  nodejs = pkgs.nodejs_24;
in
pkgs.stdenv.mkDerivation (finalAttrs: {
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
    fetcherVersion = 4;
    hash = "sha256-z2pqCgG3lPUawQA1x/VkaouQZ4dTlhx17SRVXYF3R7A=";
  };

  nativeBuildInputs = [
    pkgs.makeBinaryWrapper
    pkgs.pnpm
    pkgs.pnpmConfigHook
    nodejs
  ];

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Reinstall to remove dev packages retained in node_modules/.pnpm.
    rm -rf node_modules
    pnpm install --prod --offline --ignore-scripts --frozen-lockfile

    mkdir -p "$out/lib/acpx"
    cp -r dist node_modules package.json skills "$out/lib/acpx"

    # Built-in adapters need npx. The resolved node binary lives in nodejs-slim,
    # so acpx cannot find npm beside process.execPath.
    makeWrapper "${nodejs}/bin/node" "$out/bin/acpx" \
      --add-flags "$out/lib/acpx/dist/cli.js" \
      --suffix PATH : "${lib.makeBinPath [ nodejs ]}"

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
