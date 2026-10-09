# ==================================================================================================
# Completeness Gate
# ==================================================================================================

{
  event = "Stop";
  type = "prompt";
  statusMessage = "Checking completeness";
  prompt = builtins.readFile ./prompt.md;
}
