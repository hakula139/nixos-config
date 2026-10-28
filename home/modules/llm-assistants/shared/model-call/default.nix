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
  name = "${assistant}-model-call";
  script = ./model-call.nu;
  config = {
    inherit gateway curlArgs;
    curl = lib.getExe pkgs.curl;
  };
})
