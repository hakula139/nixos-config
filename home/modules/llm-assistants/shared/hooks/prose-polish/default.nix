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
      # Every Markdown file under this tree is a prompt, a doctrine fragment, or
      # a skill body, and `phrasing.md` is this hook's own system prompt. A
      # reworded copy silently changes what the model is told.
      excludedPaths = [ "home/modules/llm-assistants/" ];
      model = "openrouter/google/gemini-3.7-flash";
      phrasing = builtins.readFile ../../instructions/phrasing.md;
      prompt = builtins.readFile ./prose-polish-prompt.md;
    };
  };
}
