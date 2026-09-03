# ==============================================================================
# Prose Polish Hook
# ==============================================================================

{
  mkNuHook,
  modelCall,
  timeouts,
}:

let
  mcpProseFields = builtins.fromJSON (builtins.readFile ./mcp-fields.json);
in
{
  event = "PreToolUse";
  tools = [
    "askQuestion"
    "fileWrite"
  ]
  ++ builtins.attrNames mcpProseFields;
  statusMessage = "Polishing prose";
  timeout = timeouts.prosePolish;
  command = mkNuHook {
    slug = "prose-polish";
    script = ./prose-polish.nu;
    config = {
      inherit mcpProseFields modelCall;
      model = "openrouter/google/gemini-3.7-flash";
      phrasing = builtins.readFile ../../instructions/phrasing.md;
      prompt = builtins.readFile ./prompt.md;
      repairPrompt = builtins.readFile ./repair-prompt.md;
    };
  };
}
