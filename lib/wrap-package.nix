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
  envVars ? { },
  envFiles ? { },
}:

let
  esc = lib.escapeShellArg;

  # Static values follow raw arguments, which may load a dynamic environment.
  envVarArgs = lib.concatLists (
    lib.mapAttrsToList (name: value: [
      "--set"
      name
      value
    ]) envVars
  );

  # File contents are read at launch so secrets stay out of the store.
  envFileArgs = lib.concatLists (
    lib.mapAttrsToList (name: file: [
      "--run"
      ''export ${esc name}="$(${lib.getExe' pkgs.coreutils "cat"} ${esc file})"''
    ]) envFiles
  );
in
pkgs.symlinkJoin {
  inherit name;
  paths = [ pkg ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    # Renaming a shell launcher can change the argv[0] it forwards.
    rm "$out/bin/"${esc bin}
    makeWrapper ${esc (lib.getExe' pkg bin)} "$out/bin/"${esc bin} \
      ${lib.escapeShellArgs (wrapArgs ++ envVarArgs ++ envFileArgs)}
  '';
}
