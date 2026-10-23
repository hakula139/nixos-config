# ==================================================================================================
# Completeness Gate Hook
# ==================================================================================================

{
  timeouts,
}:

{
  event = "Stop";
  type = "prompt";
  timeout = timeouts.modelCall;
  statusMessage = "Checking completeness";
  prompt = builtins.readFile ./prompt.md;
}
