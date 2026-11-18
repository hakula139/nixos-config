# ==================================================================================================
# Auto-Dream Hook
# ==================================================================================================

{
  pkgs,
  lib,
  sharedHooks,
  model,
}:

{
  event = "SessionStart";
  type = "command";
  timeout = sharedHooks.timeouts.tool;
  statusMessage = "Checking memory consolidation";
  command = sharedHooks.mkNuHook {
    slug = "auto-dream";
    script = ./auto-dream.nu;
    config = {
      git = lib.getExe pkgs.git;
      inherit model;
      prompt = builtins.readFile ./prompt.md;
    };
  };
}
