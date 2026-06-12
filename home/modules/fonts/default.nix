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
  script = pkgs.copyPathToStore ./install-windows-fonts.sh;
  windowsInterop = pkgs.copyPathToStore wslLib.windowsInteropScript;

  installWindowsFonts = pkgs.writeShellApplication {
    name = "install-windows-fonts";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${script} ${windowsInterop} ${
        lib.concatMapStringsSep " " lib.escapeShellArg fontDirs
      }
    '';
  };
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
