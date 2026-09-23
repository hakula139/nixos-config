# ==============================================================================
# Completeness Gate
# ==============================================================================

{
  event = "Stop";
  type = "agent";
  statusMessage = "Checking completeness";
  prompt = builtins.readFile ./prompt.md;
}
