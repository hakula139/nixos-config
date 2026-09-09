# ==============================================================================
# Completeness Gate
# ==============================================================================

{
  assistant,
  mkNuHook,
  modelCall,
  timeouts,
}:

let
  prompt = builtins.readFile ./prompt.md;
in
{
  inherit prompt;
  event = "Stop";
  timeout = 2 * timeouts.modelCall + timeouts.tool;
  statusMessage = "Checking completeness";
  command = mkNuHook {
    slug = "completeness";
    script = ./completeness.nu;
    config = {
      inherit assistant modelCall prompt;
    };
  };
}
