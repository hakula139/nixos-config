# ==================================================================================================
# Comment Gate Hook
# ==================================================================================================

{
  mkNuHook,
  timeouts,
  modelCall,
  modelCatalog,
  promptFragments,
  patchInput,
}:

{
  event = "PostToolUse";
  type = "command";
  tools = [ "fileWrite" ];
  usesGateway = true;
  timeout = timeouts.modelCall + timeouts.modelHookMargin;
  statusMessage = "Checking comments";
  command = mkNuHook {
    slug = "comment-gate";
    script = ./comment-gate.nu;
    config = {
      inherit modelCall patchInput;
      model = modelCatalog.models.${modelCatalog.defaults.gemini.mini}.channelId.google;
      prompt = promptFragments.readPrompt ./prompt.md;
    };
  };
}
