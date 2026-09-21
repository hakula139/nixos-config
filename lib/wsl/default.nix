# ==============================================================================
# WSL Helper Library
# ==============================================================================

{
  lib,
}:

{
  mkWindowsInterop =
    pkgs:
    let
      package = pkgs.writers.writeNuBin "windows-interop" (builtins.readFile ./windows-interop.nu);
    in
    lib.getExe package;
}
