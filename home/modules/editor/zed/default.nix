# ==================================================================================================
# Zed Editor Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
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
      inherit (inputs.devkit.lib.mkLib pkgs) dprint dprintConfig;

      markdownFormatter = pkgs.writeShellApplication {
        name = "devkit-format-markdown";
        text = ''
          exec ${lib.getExe dprint} fmt \
            --config ${dprintConfig} \
            --stdin md
        '';
      };

      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      settings = import ./settings.nix {
        inherit pkgs lib repoLib;
        inherit (config.agents) acp;
        markdownFormatterCommand = lib.getName markdownFormatter;
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
      # Packages
      # --------------------------------------------------------------------------------------------
      home.packages = [
        markdownFormatter
      ]
      ++ lib.optional cfg.windowsSync.enable windowsSync.syncWindowsSettings;
    }
  );
}
