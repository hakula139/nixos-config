# ==============================================================================
# Prose Tic Candidates
# ==============================================================================

{ writers }:

writers.writeNu "prose-candidates" (builtins.readFile ./prose-candidates.nu)
