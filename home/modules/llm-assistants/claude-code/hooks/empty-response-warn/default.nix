# ==================================================================================================
# Empty Response Warning Hook
# ==================================================================================================

{
  sharedHooks,
}:

{
  event = "Stop";
  type = "command";
  command = sharedHooks.mkNuHook {
    slug = "empty-response-warn";
    script = ./empty-response-warn.nu;
  };
}
