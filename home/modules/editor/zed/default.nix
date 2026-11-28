# ==================================================================================================
# Zed Editor Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.zed;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.zed = {
    enable = lib.mkEnableOption "Zed editor configuration";

    windowsSync = {
      enable = lib.mkEnableOption "syncing Zed settings and keymaps to Windows (WSL only)";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      settings = import ./settings.nix {
        inherit pkgs lib repoLib;
      };

      windowsSync = import ./windows-sync.nix {
        inherit pkgs repoLib;
        inherit (settings) windowsSettingsJson windowsKeymapsJson;
      };
    in
    {
      # --------------------------------------------------------------------------------------------
      # Editor configuration
      # --------------------------------------------------------------------------------------------
      programs.zed-editor = {
        enable = true;
        package = null;
        installRemoteServer = false;
        mutableUserSettings = true;
        mutableUserKeymaps = true;
        inherit (settings) extensions userSettings userKeymaps;
      };

      # --------------------------------------------------------------------------------------------
      # Windows sync
      # --------------------------------------------------------------------------------------------
      home.packages = lib.optional cfg.windowsSync.enable windowsSync.syncWindowsSettings;
    }
  );
}
