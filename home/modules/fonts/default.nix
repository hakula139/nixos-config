# ==============================================================================
# Windows Font Sync (WSL only)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  sharedConfig,
  wslLib,
  ...
}:

let
  shared = sharedConfig { inherit pkgs lib; };
  cfg = config.hakula.fonts;

  fontDirs = map (p: "${p}/share/fonts") shared.fonts;

  installWindowsFonts = pkgs.writers.writeNuBin "install-windows-fonts" (
    builtins.replaceStrings
      [
        "@windowsInterop@"
        "@fontDirs@"
      ]
      [
        "${pkgs.copyPathToStore wslLib.windowsInteropScript}"
        (builtins.toJSON fontDirs)
      ]
      (builtins.readFile ./install-windows-fonts.nu)
  );
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.fonts = {
    windowsSync.enable = lib.mkEnableOption "syncing Nix-managed fonts to Windows (WSL only)";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.windowsSync.enable {
    # Home Manager activation can run outside the interactive WSL session where
    # Windows interop works. Expose the command and let nixsw trigger it.
    home.packages = [ installWindowsFonts ];
  };
}
