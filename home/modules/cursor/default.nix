{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cursor Configuration
# ==============================================================================

let
  cfg = config.hakula.cursor;
  isDarwin = pkgs.stdenv.isDarwin;
  ext = import ./extensions.nix { inherit lib; };

  # ----------------------------------------------------------------------------
  # Settings Generation
  # ----------------------------------------------------------------------------
  settingsBase = builtins.fromJSON (builtins.readFile ./settings.json);
  settingsOverrides = import ./settings.nix { inherit pkgs; };
  settings = lib.recursiveUpdate settingsBase settingsOverrides;
  settingsJson = (pkgs.formats.json { }).generate "cursor-settings.json" settings;

  # ----------------------------------------------------------------------------
  # User Files
  # ----------------------------------------------------------------------------
  userFiles =
    if isDarwin then
      {
        "Library/Application Support/Cursor/User/settings.json".source = settingsJson;
        "Library/Application Support/Cursor/User/keybindings.json".source = ./keybindings.json;
        "Library/Application Support/Cursor/User/snippets".source = ./snippets;
      }
    else
      {
        "Cursor/User/settings.json".source = settingsJson;
        "Cursor/User/keybindings.json".source = ./keybindings.json;
        "Cursor/User/snippets".source = ./snippets;
      };

  # ----------------------------------------------------------------------------
  # Cursor Paths
  # ----------------------------------------------------------------------------
  paths =
    if isDarwin then
      [
        "/usr/local/bin"
        "/Applications/Cursor.app/Contents/Resources/app/bin"
      ]
    else
      [
        "/usr/local/bin"
        "/usr/bin"
      ];
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.hakula.cursor = {
    enable = lib.mkEnableOption "Cursor configuration";

    enableExtensions = lib.mkEnableOption "Cursor extensions";
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # User Configuration Files
    # --------------------------------------------------------------------------
    home.file = lib.optionalAttrs isDarwin userFiles;
    xdg.configFile = lib.optionalAttrs (!isDarwin) userFiles;

    # --------------------------------------------------------------------------
    # Extension Management
    # --------------------------------------------------------------------------
    home.activation.cursorExtensions = lib.mkIf cfg.enableExtensions (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${lib.concatStringsSep ":" paths}:$PATH"

        if command -v cursor &>/dev/null; then
          ${ext.installScript}
        else
          echo "Cursor not found, skipping extension installation"
        fi
      ''
    );
  };
}
