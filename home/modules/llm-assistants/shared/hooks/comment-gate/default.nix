# ==============================================================================
# Comment Gate Hook
# ==============================================================================

{
  mkNuHook,
  modelCall,
  commentGate,
  patchInput,
  timeouts,
}:

{
  event = "PostToolUse";
  tools = [ "fileWrite" ];
  timeout = 2 * timeouts.modelCall;
  statusMessage = "Checking comments";
  command = mkNuHook {
    slug = "comment-gate";
    script = ./comment-gate.nu;
    config = {
      inherit modelCall;
      patchInput = toString patchInput;
      prompt = commentGate;
    };
  };
}
