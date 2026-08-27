# ==============================================================================
# PreToolUse Hooks
# ==============================================================================

{
  mkHookScript,
  timeouts,
  writePython,
  zhDoctrine,
}:

{
  zhPolish = mkHookScript {
    slug = "zh-polish";
    script = ./zh-polish/zh-polish.py;
    writer = writePython;
    substitutions = {
      "@promptFile@" = "${./zh-polish/zh-polish-prompt.md}";
      "@doctrineFile@" = "${zhDoctrine}";
      "@model@" = "openrouter/google/gemini-3.7-flash";
      "@polishTimeout@" = toString timeouts.modelCall;
    };
  };
}
