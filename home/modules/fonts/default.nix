{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Windows Font Sync (WSL only)
# ==============================================================================

let
  shared = import ../../../modules/shared.nix { inherit pkgs; };
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
    home.packages = [ installWindowsFonts ];

    home.activation.installWindowsFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${installWindowsFonts}/bin/install-windows-fonts
    '';
  };
}
