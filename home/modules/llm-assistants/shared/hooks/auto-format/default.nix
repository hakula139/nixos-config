# ==================================================================================================
# Auto-Format Hook
# ==================================================================================================

{
  formatFiles,
  mkNuHook,
  patchInput,
  timeouts,
}:

{
  event = "PostToolUse";
  type = "command";
  tools = [ "fileWrite" ];
  timeout = timeouts.postEdit;
  statusMessage = "Formatting edited files";
  command = mkNuHook {
    slug = "auto-format";
    script = ./auto-format.nu;
    config = {
      inherit formatFiles;
      patchInput = toString patchInput;
    };
  };
}
