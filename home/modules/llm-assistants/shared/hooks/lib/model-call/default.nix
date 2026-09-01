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
      # Resolved from PATH like the other unpinned toolchains, so a server
      # closure does not carry it and the leg uses the profile's own auth.
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
