# ==================================================================================================
# Compact Context Hook
# ==================================================================================================

{
  mkNuHook,
  timeouts,
}:

{
  event = "SessionStart";
  type = "command";
  matcher = "compact";
  timeout = timeouts.tool;
  statusMessage = "Restoring compacted context";
  command = mkNuHook {
    slug = "compact-context";
    script = ./compact-context.nu;
    config = {
      prompt = builtins.readFile ./prompt.md;
    };
  };
}
