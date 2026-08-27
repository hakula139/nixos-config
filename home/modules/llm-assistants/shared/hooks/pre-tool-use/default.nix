# ==============================================================================
# PreToolUse Hooks
# ==============================================================================

{
  pkgs,
  lib,
  mkHookScript,
  timeouts,
  zhDoctrine,
}:

{
  zhPolish = mkHookScript {
    slug = "zh-polish";
    script = ./zh-polish/zh-polish.nu;
    writer = pkgs.writers.writeNu;
    substitutions = {
      "@promptFile@" = "${./zh-polish/zh-polish-prompt.md}";
      "@doctrineFile@" = "${zhDoctrine}";
      "@model@" = "openrouter/google/gemini-3.7-flash";
      "@polishTimeout@" = toString timeouts.modelCall;
      "@curl@" = lib.getExe pkgs.curl;
    };
  };
}
