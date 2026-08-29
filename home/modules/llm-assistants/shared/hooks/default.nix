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
      package = pkgs.writers.writeNuBin "${assistant}-${slug}" {
        makeWrapperArgs = [
          "--add-flag"
          "${configFile}"
        ];
      } (builtins.readFile script);
    in
    "${package}/bin/${assistant}-${slug}";

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
