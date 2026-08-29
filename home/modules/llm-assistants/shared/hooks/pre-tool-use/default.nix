# ==============================================================================
# PreToolUse Hooks
# ==============================================================================

{
  pkgs,
  lib,
  mkHookScript,
  proseDoctrine,
  timeouts,
}:

let
  mcpProseFieldsFile = ./prose-polish/mcp-fields.json;
  mcpProseFields = builtins.fromJSON (builtins.readFile mcpProseFieldsFile);
in
{
  inherit mcpProseFields;

  prosePolish = mkHookScript {
    slug = "prose-polish";
    script = ./prose-polish/prose-polish.nu;
    writer = pkgs.writers.writeNu;
    substitutions = {
      "@curl@" = lib.getExe pkgs.curl;
      "@doctrineFile@" = "${proseDoctrine}";
      "@promptFile@" = "${./prose-polish/prose-polish-prompt.md}";
      "@model@" = "openrouter/google/gemini-3.7-flash";
      "@mcpProseFields@" = builtins.readFile mcpProseFieldsFile;
      "@polishTimeout@" = toString timeouts.modelCall;
    };
  };
}
