# ==================================================================================================
# Shared Model Call
# ==================================================================================================

{
  pkgs,
  lib,
  assistant,
  gateway,
  mkNuCommand,
  timeouts,
}:

lib.getExe (mkNuCommand {
  name = "${assistant}-model-call";
  script = ./model-call.nu;
  config = {
    inherit gateway;
    curl = lib.getExe pkgs.curl;
    connectTimeout = timeouts.modelConnect;
    timeout = timeouts.modelCall;
  };
})
