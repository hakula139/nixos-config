{ pkgs }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "subconverter";
  version = "0.9.2";

  src = pkgs.fetchzip {
    url = "https://github.com/MetaCubeX/subconverter/releases/download/v${version}/subconverter_linux64.tar.gz";
    sha256 = "sha256-t3TlTeKviKZlHOwT+bnNnKS0EM9b9tFOn5KW0Q016GQ=";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp subconverter $out/bin/
  '';

  meta = with pkgs.lib; {
    description = "Utility to convert between various proxy subscription formats";
    homepage = "https://github.com/MetaCubeX/subconverter";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
