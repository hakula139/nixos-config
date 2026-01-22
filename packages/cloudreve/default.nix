{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve (Self-hosted Cloud Storage)
# ==============================================================================

let
  version = "4.11.1";
  baseUrl = "https://github.com/cloudreve/cloudreve/releases/download/${version}";

  sources = {
    x86_64-linux = {
      url = "${baseUrl}/cloudreve_${version}_linux_amd64.tar.gz";
      hash = "sha256-8dsRJgEf3fMZm+m6tD+oTrtWcxWsrGJYXzZC941E3rE=";
    };
  };

  platform = pkgs.stdenv.hostPlatform.system;
  source = sources.${platform} or (throw "Unsupported platform: ${platform}");
in
pkgs.stdenv.mkDerivation {
  pname = "cloudreve";
  inherit version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
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
    platforms = builtins.attrNames sources;
    mainProgram = "cloudreve";
  };
}
