# ==============================================================================
# WakaTime Hook
# ==============================================================================

{
  pkgs,
  assistant,
  mkNuHook,
  timeouts,
}:

mkNuHook {
  slug = "wakatime-heartbeat";
  script = ./wakatime.nu;
  config = {
    pluginName = "${assistant}-hook/1.0";
    timeout = "${pkgs.coreutils}/bin/timeout";
    toolTimeout = timeouts.tool;
  };
}
