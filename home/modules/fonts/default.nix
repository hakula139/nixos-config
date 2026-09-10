# ==============================================================================
# Windows Font Sync (WSL only)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  json = pkgs.formats.json { };
  cfg = config.hakula.fonts;

  fontDirs = map (p: "${p}/share/fonts") (repoLib.packagesFor pkgs).fonts;
  windowsInterop = repoLib.wsl.mkWindowsInterop pkgs;
  fontConfig = json.generate "windows-fonts.json" {
    inherit fontDirs windowsInterop;
  };

  installWindowsFonts = pkgs.writers.writeNuBin "install-windows-fonts" {
    makeWrapperArgs = [
      "--add-flag"
      "${fontConfig}"
    ];
  } (builtins.readFile ./install-windows-fonts.nu);
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
