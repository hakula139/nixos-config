# ==================================================================================================
# Shared Model Call
# ==================================================================================================

{
  pkgs,
  lib,
  gateway,
  mkNuHook,
  timeouts,
}:

{
  modelCall = mkNuHook {
    slug = "model-call";
    script = ./model-call.nu;
    config = {
      inherit gateway;
      curl = lib.getExe pkgs.curl;
      connectTimeout = timeouts.modelConnect;
      timeout = timeouts.modelCall;
    };
  };
}
