# ==============================================================================
# Package Wrapper
# ==============================================================================

{
  lib,
}:

{
  pkgs,
  pkg,
  name ? pkg.name,
  bin ? pkg.pname or pkg.name,
  wrapArgs ? [ ],
}:

pkgs.symlinkJoin {
  inherit name;
  paths = [ pkg ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    # Renaming a shell launcher can change the argv[0] it forwards.
    rm "$out/bin/"${lib.escapeShellArg bin}
    makeWrapper ${lib.escapeShellArg (lib.getExe' pkg bin)} "$out/bin/"${lib.escapeShellArg bin} \
      ${lib.escapeShellArgs wrapArgs}
  '';
}
