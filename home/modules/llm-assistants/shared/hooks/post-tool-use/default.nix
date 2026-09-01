# ==============================================================================
# PostToolUse Hooks
# ==============================================================================

{
  pkgs,
  lib,
  assistant,
  enableDevToolchains,
  mkNuHook,
  modelCall,
  instructionsDir,
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
// import ./comment-gate {
  inherit
    mkNuHook
    modelCall
    instructionsDir
    ;
}
