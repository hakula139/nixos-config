# ==============================================================================
# zsh-hist
# ==============================================================================

{
  stdenvNoCC,
  fetchFromGitHub,
  lib,
}:

stdenvNoCC.mkDerivation {
  pname = "zsh-hist";
  version = "0-unstable-2026-02-13";

  src = fetchFromGitHub {
    owner = "marlonrichert";
    repo = "zsh-hist";
    rev = "b2e65350660bdeb20f1a3059a7540c247a21b87d";
    hash = "sha256-5V0uTXYh2JmVr2v+tBkjpekx+f/OSPGz0+i8/1SrZK0=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 zsh-hist.plugin.zsh -t $out/share/zsh-hist
    install -Dm644 _hist -t $out/share/zsh-hist
    cp -r functions $out/share/zsh-hist/functions
    runHook postInstall
  '';

  meta = {
    description = "Edit your Zsh history from the command line";
    homepage = "https://github.com/marlonrichert/zsh-hist";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
