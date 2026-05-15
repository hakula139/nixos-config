# ==============================================================================
# Windows Font Sync (WSL only)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  sharedConfig,
  ...
}:

let
  shared = sharedConfig { inherit pkgs lib; };
  cfg = config.hakula.fonts;

  fontDirs = map (p: "${p}/share/fonts") shared.fonts;
  script = pkgs.copyPathToStore ./install-windows-fonts.sh;

  installWindowsFonts = pkgs.writeShellApplication {
    name = "install-windows-fonts";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${script} ${lib.concatMapStringsSep " " lib.escapeShellArg fontDirs}
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

  config = lib.mkIf cfg.windowsSync.enable {
    # Home Manager runs as a systemd service under system-manager, where WSL
    # interop is unavailable, so cmd.exe / wslpath / reg.exe fail. Expose
    # install-windows-fonts on PATH and let the nixsw alias trigger it from
    # the user's interactive shell instead.
    home.packages = [ installWindowsFonts ];
  };
}
