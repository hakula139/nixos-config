# ==================================================================================================
# Repository Library
# ==================================================================================================

{
  lib,
}:

let
  wrapPackage = import ./wrap-package.nix {
    inherit lib;
  };
  mkNuCommand = import ./nu-command.nix {
    inherit lib wrapPackage;
  };
  proxy = import ./proxy.nix {
    inherit lib wrapPackage;
  };
in
{
  inherit
    wrapPackage
    mkNuCommand
    proxy
    ;

  aria2 = import ./aria2.nix;
  llmAssistants = import ./llm-assistants { inherit lib; };
  mihomo = import ./mihomo { inherit lib mkNuCommand proxy; };
  packagesFor = pkgs: import ./packages.nix { inherit pkgs; };
  secrets = import ./secrets.nix { inherit lib; };
  ssh = import ./ssh.nix { inherit lib; };
  systemd = import ./systemd.nix { inherit lib; };
  toolingFor = pkgs: import ./tooling.nix { inherit pkgs; };
  wsl = import ./wsl { inherit lib; };
}
