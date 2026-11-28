# ==================================================================================================
# Repository Library
# ==================================================================================================

{
  lib,
  devkit,
}:

let
  nuRuntimeFiles = lib.fileset.fileFilter (
    file: !(lib.hasSuffix ".test.nu" file.name || lib.hasSuffix ".testlib.nu" file.name)
  ) ./nu;

  nuModules = lib.fileset.toSource {
    root = ./nu;
    fileset = nuRuntimeFiles;
  };

  nuTestLib = lib.fileset.toSource {
    root = ./nu;
    fileset = lib.fileset.union nuRuntimeFiles (
      lib.fileset.fileFilter (file: lib.hasSuffix ".testlib.nu" file.name) ./nu
    );
  };

  mkNuCommand = import ./nu-command { inherit lib devkit nuModules; };
  proxy = import ./proxy.nix { inherit lib; };
  wrapPackage = import ./wrap-package.nix { inherit lib; };
in
{
  inherit
    mkNuCommand
    nuTestLib
    proxy
    wrapPackage
    ;

  agents = import ./agents.nix { inherit lib; };
  aria2 = import ./aria2.nix;
  hosts = import ./hosts { inherit mkNuCommand; };
  mihomo = import ./mihomo { inherit lib mkNuCommand proxy; };
  packagesFor = pkgs: import ./packages.nix { inherit pkgs; };
  secrets = import ./secrets.nix { inherit lib; };
  ssh = import ./ssh.nix { inherit lib; };
  systemd = import ./systemd.nix { inherit lib; };
  telemetry = import ./telemetry.nix { inherit lib; };
  toolingFor = pkgs: import ./tooling.nix { inherit pkgs; };
  wsl = import ./wsl { inherit lib; };
}
