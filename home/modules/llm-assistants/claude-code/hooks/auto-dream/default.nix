# ==================================================================================================
# Auto-Dream Hook
# ==================================================================================================

{
  pkgs,
  lib,
  mkNuHook,
  model,
  timeouts,
}:

{
  event = "SessionStart";
  type = "command";
  timeout = timeouts.tool;
  statusMessage = "Checking memory consolidation";
  command = mkNuHook {
    slug = "auto-dream";
    script = ./auto-dream.nu;
    config = {
      git = lib.getExe pkgs.git;
      inherit model;
      prompt = builtins.readFile ./prompt.md;
    };
  };
}
