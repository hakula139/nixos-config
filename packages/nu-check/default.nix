# ==============================================================================
# Nushell Diagnostic Check
# ==============================================================================

{
  pkgs,
}:

pkgs.writers.writeNu "nu-check" (builtins.readFile ./nu-check.nu)
