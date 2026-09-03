# ==============================================================================
# Completeness Gate
# ==============================================================================

{
  event = "Stop";
  statusMessage = "Checking completeness";
  prompt = builtins.readFile ./prompt.md;
}
