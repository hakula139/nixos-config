# ==============================================================================
# ACPX – ACP Client
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  # tsdown, the upstream build tool, rejects Node 25 and wants 22.18+ or 24.11+.
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

    # `pnpm install --prod` rewrites the top-level links but leaves every dev
    # package in `node_modules/.pnpm`, so reinstall into an empty tree.
    rm -rf node_modules
    pnpm install --prod --offline --ignore-scripts --frozen-lockfile

    mkdir -p "$out/lib/acpx"
    cp -r dist node_modules package.json skills "$out/lib/acpx"

    # Built-in adapters spawn as literal `npx` commands, and acpx's fallback to
    # the npm beside `process.execPath` misses because nodejs_24's `bin/node`
    # symlinks into nodejs-slim, which ships no npm.
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
