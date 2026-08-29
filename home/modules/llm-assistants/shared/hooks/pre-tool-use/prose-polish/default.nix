# ==============================================================================
# Prose Polish Hook
# ==============================================================================

{
  pkgs,
  lib,
  mkNuHook,
  timeouts,
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
      curl = lib.getExe pkgs.curl;
      inherit mcpProseFields;
      model = "openrouter/google/gemini-3.7-flash";
      phrasing = builtins.readFile ../../../instructions/phrasing.md;
      polishTimeout = timeouts.modelCall;
      prompt = builtins.readFile ./prose-polish-prompt.md;
    };
  };
}
