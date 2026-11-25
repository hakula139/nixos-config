# ==================================================================================================
# Cursor Windows Sync
# ==================================================================================================

{
  pkgs,
  repoLib,
  windowsSettingsJson,
}:

{
  syncWindowsSettings = repoLib.mkNuCommand {
    inherit pkgs;
    name = "sync-windows-cursor-settings";
    script = ./scripts/sync-windows-settings.nu;

    config = {
      keybindingsFile = ./keybindings.json;
      settingsFile = windowsSettingsJson;
      windowsInterop = repoLib.wsl.mkWindowsInterop pkgs;
    };
  };
}
