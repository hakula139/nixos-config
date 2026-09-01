# ==============================================================================
# Prose Polish Hook
# ==============================================================================

{
  mkNuHook,
  modelCall,
}:

let
  mcpProseFieldsFile = ./mcp-fields.json;
  mcpProseFields = builtins.fromJSON (builtins.readFile mcpProseFieldsFile);
in
{
  inherit mcpProseFields;

  prosePolish = mkNuHook {
    slug = "prose-polish";
    script = ./prose-polish.nu;
    config = {
      inherit mcpProseFields modelCall;
      model = "openrouter/google/gemini-3.7-flash";
      phrasing = builtins.readFile ../../../instructions/phrasing.md;
      prompt = builtins.readFile ./prose-polish-prompt.md;
    };
  };
}
