# ==================================================================================================
# Nushell Application Builder
# ==================================================================================================

{
  pkgs,
  lib,
}:

{
  name,
  src,
  runtimeInputs ? [ ],
  meta ? { },
}:

let
  excluded =
    file:
    file.name == "default.nix"
    || lib.hasSuffix ".test.nu" file.name
    || lib.hasSuffix ".stub.nu" file.name;
in
pkgs.stdenvNoCC.mkDerivation {
  inherit name;

  src = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.difference src (lib.fileset.fileFilter excluded src);
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  # Nushell names a script's usage after its file, so the entry is linked under the tool's name.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -r . "$out/share/${name}"
    ln -s main.nu "$out/share/${name}/${name}"
    makeWrapper ${lib.getExe pkgs.nushell} "$out/bin/${name}" \
      --prefix PATH : ${lib.makeBinPath runtimeInputs} \
      --add-flags "--no-config-file $out/share/${name}/${name}"
    runHook postInstall
  '';

  meta = {
    mainProgram = name;
  }
  // meta;
}
