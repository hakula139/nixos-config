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

  proseDoctrine = ../instructions/phrasing.md;

  # ----------------------------------------------------------------------------
  # Script generation
  # ----------------------------------------------------------------------------
  mkHookScript =
    {
      slug,
      script,
      substitutions ? { },
      writer ? pkgs.writeShellScript,
    }:
    writer "${assistant}-${slug}" (
      builtins.replaceStrings (builtins.attrNames substitutions) (builtins.attrValues substitutions) (
        builtins.readFile script
      )
    );

  preToolUseHooks = import ./pre-tool-use {
    inherit
      pkgs
      lib
      mkHookScript
      proseDoctrine
      timeouts
      ;
  };
  postToolUseHooks = import ./post-tool-use {
    inherit
      pkgs
      lib
      assistant
      enableDevToolchains
      mkHookScript
      repo
      timeouts
      ;
  };
  stopHooks = import ./stop;
in
{ inherit timeouts; } // preToolUseHooks // postToolUseHooks // stopHooks
