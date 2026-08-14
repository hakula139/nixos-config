# ==============================================================================
# Nushell Diagnostic Check
# ==============================================================================

{ writers }:

writers.writeNu "nu-check" (builtins.readFile ./nu-check.nu)
