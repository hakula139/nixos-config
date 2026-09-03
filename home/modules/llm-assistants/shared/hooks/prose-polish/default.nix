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
  # Each round of feedback removes some of the faults but rarely all of them, so
  # a document dense with protected spans needs several to converge.
  maxRepairs = 3;
in
{
  event = "PreToolUse";
  tools = [
    "askQuestion"
    "fileWrite"
  ]
  ++ builtins.attrNames mcpProseFields;
  statusMessage = "Polishing prose";
  timeout = (1 + maxRepairs) * timeouts.modelCall;
  command = mkNuHook {
    slug = "prose-polish";
    script = ./prose-polish.nu;
    config = {
      inherit maxRepairs mcpProseFields modelCall;
      model = "openrouter/google/gemini-3.7-flash";
      phrasing = builtins.readFile ../../instructions/phrasing.md;
      prompt = builtins.readFile ./prompt.md;
      repairPrompt = builtins.readFile ./repair-prompt.md;
    };
  };
}
