# ==================================================================================================
# zsh-hist
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "zsh-hist";
  version = "0-unstable-2026-02-13";

  src = pkgs.fetchFromGitHub {
    owner = "marlonrichert";
    repo = "zsh-hist";
    rev = "b2e65350660bdeb20f1a3059a7540c247a21b87d";
    hash = "sha256-5V0uTXYh2JmVr2v+tBkjpekx+f/OSPGz0+i8/1SrZK0=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm0644 \
      -t "$out/share/zsh-hist" \
      zsh-hist.plugin.zsh _hist
    cp -r functions "$out/share/zsh-hist/functions"
    runHook postInstall
  '';

  meta = {
    description = "Edit your Zsh history from the command line";
    homepage = "https://github.com/marlonrichert/zsh-hist";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
