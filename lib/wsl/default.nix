# ==============================================================================
# WSL Helper Library
# ==============================================================================

{
  mkWindowsInterop =
    pkgs:
    let
      package = pkgs.writers.writeNuBin "windows-interop" (builtins.readFile ./windows-interop.nu);
    in
    "${package}/bin/windows-interop";
}
