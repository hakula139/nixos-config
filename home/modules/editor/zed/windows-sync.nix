# ==================================================================================================
# Zed Windows Sync
# ==================================================================================================

{
  pkgs,
  repoLib,
  windowsSettingsJson,
  windowsKeymapsJson,
}:

{
  syncWindowsSettings = repoLib.mkNuCommand {
    inherit pkgs;
    name = "sync-windows-zed-settings";
    script = ./scripts/sync-windows-settings.nu;

    config = {
      keymapFile = windowsKeymapsJson;
      settingsFile = windowsSettingsJson;
      windowsInterop = repoLib.wsl.mkWindowsInterop pkgs;
    };
  };
}
