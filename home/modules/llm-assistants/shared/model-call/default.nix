# ==================================================================================================
# Shared Model Call
# ==================================================================================================

{
  pkgs,
  lib,
  assistant,
  gateway,
  curlArgs,
  mkNuCommand,
}:

lib.getExe (mkNuCommand {
  inherit pkgs;
  name = "${assistant}-model-call";
  script = ./model-call.nu;
  runtimeInputs = [ pkgs.coreutils ];

  config = {
    inherit gateway curlArgs;
    curl = lib.getExe pkgs.curl;
  };
})
