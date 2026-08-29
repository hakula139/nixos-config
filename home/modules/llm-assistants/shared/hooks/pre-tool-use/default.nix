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

{
  prosePolish = mkHookScript {
    slug = "prose-polish";
    script = ./prose-polish/prose-polish.nu;
    writer = pkgs.writers.writeNu;
    substitutions = {
      "@curl@" = lib.getExe pkgs.curl;
      "@doctrineFile@" = "${proseDoctrine}";
      "@promptFile@" = "${./prose-polish/prose-polish-prompt.md}";
      "@model@" = "openrouter/google/gemini-3.7-flash";
      "@polishTimeout@" = toString timeouts.modelCall;
    };
  };
}
