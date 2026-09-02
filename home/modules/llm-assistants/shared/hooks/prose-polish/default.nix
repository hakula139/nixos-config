# ==============================================================================
# Prose Polish Hook
# ==============================================================================

{
  mkNuHook,
  modelCall,
}:

let
  mcpProseFields = builtins.fromJSON (builtins.readFile ./mcp-fields.json);
in
{
  event = "PreToolUse";
  tools = [
    "askQuestion"
    "fileWrite"
  ];
  extraTools = builtins.attrNames mcpProseFields;
  statusMessage = "Polishing prose";
  command = mkNuHook {
    slug = "prose-polish";
    script = ./prose-polish.nu;
    config = {
      inherit mcpProseFields modelCall;
      model = "openrouter/google/gemini-3.7-flash";
      phrasing = builtins.readFile ../../instructions/phrasing.md;
      prompt = builtins.readFile ./prose-polish-prompt.md;
    };
  };
}
