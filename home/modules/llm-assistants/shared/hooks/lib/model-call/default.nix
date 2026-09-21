# ==============================================================================
# Shared Model Call
# ==============================================================================

{
  pkgs,
  lib,
  gateway,
  mkNuHook,
  modelCatalog,
  timeouts,
}:

{
  modelCall = mkNuHook {
    slug = "model-call";
    script = ./model-call.nu;
    config = {
      inherit gateway;
      # A bare name resolves the proxy-wrapped Codex the module puts on PATH,
      # where the unwrapped package would make its call without a proxy.
      codex = "codex";
      codexModel = modelCatalog.defaults.gpt.mini;
      codexTimeout = timeouts.modelCall;
      curl = lib.getExe pkgs.curl;
      gatewayModel = modelCatalog.models.${modelCatalog.defaults.gemini.standard}.gatewayId.openrouter;
      gatewayTimeout = timeouts.modelCall;
      timeout = lib.getExe' pkgs.coreutils "timeout";
    };
  };
}
