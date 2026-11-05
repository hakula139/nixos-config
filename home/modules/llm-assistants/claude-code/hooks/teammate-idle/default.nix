# ==================================================================================================
# Teammate Idle Hook
# ==================================================================================================

{
  pkgs,
  lib,
}:

{
  event = "TeammateIdle";
  type = "command";
  command = lib.getExe (
    pkgs.writers.writeNuBin "claude-code-teammate-idle" (builtins.readFile ./teammate-idle.nu)
  );
}
