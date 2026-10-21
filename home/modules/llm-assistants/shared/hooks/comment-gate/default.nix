# ==================================================================================================
# Comment Gate Hook
# ==================================================================================================

{
  mkNuHook,
  timeouts,
  modelCall,
  modelCatalog,
  readPrompt,
  patchInput,
}:

{
  event = "PostToolUse";
  type = "command";
  tools = [ "fileWrite" ];
  usesGateway = true;
  timeout = timeouts.modelCall;
  statusMessage = "Checking comments";
  command = mkNuHook {
    slug = "comment-gate";
    script = ./comment-gate.nu;
    config = {
      inherit modelCall;
      model = modelCatalog.models.${modelCatalog.defaults.gemini.mini}.channelId.google;
      prompt = readPrompt ./prompt.md;
      patchInput = toString patchInput;
    };
  };
}
