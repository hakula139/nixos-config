# ==============================================================================
# Shared Model Call
# ==============================================================================

{
  pkgs,
  lib,
  mkNuHook,
  timeouts,
}:

{
  modelCall = mkNuHook {
    slug = "model-call";
    script = ./model-call.nu;
    config = {
      # A bare name resolves the proxy-wrapped Codex the module puts on PATH,
      # where the unwrapped package would make its call without a proxy.
      codex = "codex";
      codexModel = "gpt-5.6-luna";
      codexTimeout = timeouts.modelCall;
      curl = lib.getExe pkgs.curl;
      gatewayModel = "openrouter/google/gemini-3.7-flash";
      gatewayTimeout = timeouts.modelCall;
      timeout = "${pkgs.coreutils}/bin/timeout";
    };
  };
}
