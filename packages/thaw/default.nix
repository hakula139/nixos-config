# ==============================================================================
# Thaw
# ==============================================================================

{
  pkgs,
  lib,
}:

pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "thaw";
  version = "3.0.0-alpha.7";

  src = pkgs.fetchurl {
    url = "https://github.com/thaw-app/Thaw/releases/download/${finalAttrs.version}/Thaw_${finalAttrs.version}.zip";
    hash = "sha256-dANNgipCGnQwQgzb3Ir6LUPhQZ7jZLZO42h9DBqNDfE=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ pkgs.unzip ];

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R Thaw.app "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Menu bar manager for macOS";
    homepage = "https://github.com/thaw-app/Thaw";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
