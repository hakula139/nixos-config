# ==============================================================================
# Comment Gate Hook
# ==============================================================================

{
  mkNuHook,
  modelCall,
  commentGate,
}:

{
  event = "PostToolUse";
  tools = [ "fileWrite" ];
  statusMessage = "Checking comments";
  command = mkNuHook {
    slug = "comment-gate";
    script = ./comment-gate.nu;
    config = {
      inherit modelCall;
      prompt = commentGate;
    };
  };
}
