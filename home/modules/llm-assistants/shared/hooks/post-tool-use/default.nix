# ==============================================================================
# PostToolUse Hooks
# ==============================================================================

{
  pkgs,
  lib,
  assistant,
  enableDevToolchains,
  mkNuHook,
  repo,
  timeouts,
}:

{
  autoFormat = import ./auto-format {
    inherit
      pkgs
      lib
      enableDevToolchains
      mkNuHook
      repo
      ;
  };
  wakatime = import ./wakatime {
    inherit
      pkgs
      assistant
      mkNuHook
      timeouts
      ;
  };
}
