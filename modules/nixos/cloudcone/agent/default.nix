# ==============================================================================
# CloudCone Agent Builder
# ==============================================================================

{
  pkgs,
  serverKeyFile,
  ...
}:

let
  inherit (pkgs) lib;

  # `inetutils` is deliberately absent: it ships a `ping` that rejects `-B`, and
  # on PATH it would shadow the one from `iputils`.
  runtimeInputs = with pkgs; [
    coreutils
    curl
    iproute2
    iputils
    procps
    util-linux
  ];
in
pkgs.writers.writeNuBin "cloudcone-agent" {
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath runtimeInputs)
  ];
} (builtins.replaceStrings [ "@serverKeyFile@" ] [ serverKeyFile ] (builtins.readFile ./agent.nu))
