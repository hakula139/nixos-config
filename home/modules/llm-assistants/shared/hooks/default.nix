# ==============================================================================
# Shared Hook Scripts
# ==============================================================================

{
  pkgs,
  lib,
  assistant,
  repo,
  enableDevToolchains ? true,
  ...
}:

let
  # ----------------------------------------------------------------------------
  # Hook timeouts
  # ----------------------------------------------------------------------------
  timeouts = rec {
    modelCall = 90;
    tool = 10;
    postEdit = 3 * tool;
  };

  # ----------------------------------------------------------------------------
  # Hook generation
  # ----------------------------------------------------------------------------
  mkNuHook =
    {
      slug,
      script,
      config,
    }:
    let
      configFile = pkgs.writeText "${assistant}-${slug}.json" (builtins.toJSON config);
    in
    pkgs.writers.writeNu "${assistant}-${slug}" {
      makeWrapperArgs = [
        "--add-flags"
        "${configFile}"
      ];
    } (builtins.readFile script);

  # ----------------------------------------------------------------------------
  # Hook groups
  # ----------------------------------------------------------------------------
  preToolUseHooks = import ./pre-tool-use {
    inherit
      pkgs
      lib
      mkNuHook
      timeouts
      ;
  };
  postToolUseHooks = import ./post-tool-use {
    inherit
      pkgs
      lib
      assistant
      enableDevToolchains
      mkNuHook
      repo
      timeouts
      ;
  };
  stopHooks = import ./stop;
in
{ inherit timeouts; } // preToolUseHooks // postToolUseHooks // stopHooks
