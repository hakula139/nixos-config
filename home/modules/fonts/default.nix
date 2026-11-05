# ==================================================================================================
# Windows Font Sync (WSL only)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.fonts;

  installWindowsFonts = repoLib.mkNuCommand {
    inherit pkgs;
    name = "install-windows-fonts";
    script = ./install-windows-fonts.nu;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iconv
      pkgs.nix
    ];

    config = {
      fontDirs = map (p: "${p}/share/fonts") (repoLib.packagesFor pkgs).fonts;
      fontsKey = ''HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'';
      windowsInterop = repoLib.wsl.mkWindowsInterop pkgs;
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.fonts = {
    windowsSync.enable = lib.mkEnableOption "syncing Nix-managed fonts to Windows (WSL only)";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.windowsSync.enable {
    # Home Manager activation can run outside the interactive WSL session where Windows interop
    # works. Expose the command and let nixsw trigger it.
    home.packages = [ installWindowsFonts ];
  };
}
