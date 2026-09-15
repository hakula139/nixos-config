# ==============================================================================
# Repository Library
# ==============================================================================

{
  lib,
}:

let
  wrapPackage = import ./wrap-package.nix { inherit lib; };
in
{
  inherit wrapPackage;

  llmAssistants = import ./llm-assistants { inherit lib; };
  packagesFor = pkgs: import ./packages.nix { inherit pkgs; };
  proxy = import ./proxy.nix { inherit lib wrapPackage; };
  secrets = import ./secrets.nix { inherit lib; };
  ssh = import ./ssh.nix { inherit lib; };
  systemd = import ./systemd.nix;
  toolingFor = pkgs: import ./tooling.nix { inherit pkgs; };
  wsl = import ./wsl;
}
