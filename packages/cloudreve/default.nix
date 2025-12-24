{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve (Self-hosted Cloud Storage)
# ==============================================================================

pkgs.stdenv.mkDerivation rec {
  pname = "cloudreve";
  version = "4.10.1";

  src = pkgs.fetchurl {
    url = "https://github.com/cloudreve/cloudreve/releases/download/${version}/cloudreve_${version}_linux_amd64.tar.gz";
    hash = "sha256-tNZg+ocgr65vyBkRDQhyX0DmLQuO0JwbXUzTeL4hSAc=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -D -m 0755 cloudreve $out/bin/cloudreve
    runHook postInstall
  '';

  meta = {
    description = "Self-hosted file management and sharing system";
    homepage = "https://cloudreve.org";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cloudreve";
  };
}
