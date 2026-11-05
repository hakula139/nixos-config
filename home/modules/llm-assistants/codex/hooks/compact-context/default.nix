# ==================================================================================================
# Compact Context Hook
# ==================================================================================================

{
  sharedHooks,
}:

{
  event = "SessionStart";
  type = "command";
  matcher = "compact";
  timeout = sharedHooks.timeouts.tool;
  statusMessage = "Restoring compacted context";
  command = sharedHooks.mkNuHook {
    slug = "compact-context";
    script = ./compact-context.nu;
    config = {
      prompt = builtins.readFile ./prompt.md;
    };
  };
}
