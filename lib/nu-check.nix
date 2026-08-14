# ==============================================================================
# Nushell Diagnostic Check Builder
# ==============================================================================
# Both the pre-commit hook and the auto-format hook need this checker, and its
# script path resolves relative to this file, so neither caller passes a root.
# ==============================================================================

{ pkgs, lib }:

pkgs.writers.writeNu "nu-check" (
  builtins.replaceStrings [ "@nu@" ] [ (lib.getExe pkgs.nushell) ] (builtins.readFile ./nu-check.nu)
)
