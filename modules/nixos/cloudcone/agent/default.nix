# ==================================================================================================
# CloudCone Agent Builder
# ==================================================================================================

{
  pkgs,
  curlArgs,
  serverKeyFile,
}:

let
  inherit (pkgs) lib;
  json = pkgs.formats.json { };

  agentConfig = json.generate "cloudcone-agent.json" {
    inherit curlArgs serverKeyFile;
  };

  # `inetutils` is deliberately absent: it ships a `ping` that rejects `-B`, and on PATH it would
  # shadow the one from `iputils`.
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

    "--add-flag"
    "${agentConfig}"
  ];
} (builtins.readFile ./agent.nu)
