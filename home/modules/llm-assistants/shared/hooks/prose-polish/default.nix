# ==================================================================================================
# Prose Polish Hook
# ==================================================================================================

{
  lib,
  mkNuHook,
  timeouts,
  modelCall,
  modelCatalog,
  phrasing,
}:

let
  mcpProseFields = lib.importJSON ./mcp-fields.json;
  maxRepairs = 3;
in
{
  event = "PreToolUse";
  type = "command";
  tools = [
    "askQuestion"
    "fileWrite"
  ]
  ++ builtins.attrNames mcpProseFields;
  usesGateway = true;
  timeout = (1 + maxRepairs) * timeouts.modelCall + timeouts.modelHookMargin;
  statusMessage = "Polishing prose";
  command = mkNuHook {
    slug = "prose-polish";
    script = ./prose-polish.nu;
    config = {
      inherit
        modelCall
        phrasing
        maxRepairs
        mcpProseFields
        ;
      model = modelCatalog.models.${modelCatalog.defaults.gemini.mini}.channelId.google;
      prompt = builtins.readFile ./prompt.md;
      repairPrompt = builtins.readFile ./repair-prompt.md;
    };
  };
}
