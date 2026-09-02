# ==============================================================================
# WakaTime Hook
# ==============================================================================

{
  pkgs,
  assistant,
  mkNuHook,
  timeouts,
}:

{
  event = "PostToolUse";
  tools = [ "fileWrite" ];
  async = true;
  command = mkNuHook {
    slug = "wakatime-heartbeat";
    script = ./wakatime.nu;
    config = {
      pluginName = "${assistant}-hook/1.0";
      timeout = "${pkgs.coreutils}/bin/timeout";
      toolTimeout = timeouts.tool;
    };
  };
}
