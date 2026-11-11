# ==================================================================================================
# Thaw
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "thaw";
  version = "3.0.0-beta.6";

  src = pkgs.fetchurl {
    url = "https://github.com/thaw-app/Thaw/releases/download/${finalAttrs.version}/Thaw_${finalAttrs.version}.zip";
    hash = "sha256-19Be46pv3xiDbx6MJ69zhoth8ojnQ6Kbi/gLBzxM/Cs=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    pkgs.unzip
  ];

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
