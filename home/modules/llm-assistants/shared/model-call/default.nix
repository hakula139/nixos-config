# ==================================================================================================
# Shared Model Call
# ==================================================================================================

{
  pkgs,
  lib,
  assistant,
  gateway,
  repoLib,
  timeouts,
}:

let
  curlArgs = [
    "-fsSL"

    "--connect-timeout"
    (toString timeouts.modelConnect)

    "--max-time"
    (toString timeouts.modelCall)
  ];
in
lib.getExe (
  repoLib.mkNuCommand {
    inherit pkgs;
    name = "${assistant}-model-call";
    script = ./model-call.nu;
    runtimeInputs = [ pkgs.coreutils ];

    config = {
      inherit gateway curlArgs;
      curl = lib.getExe pkgs.curl;
    };
  }
)
