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
    judge = 30;
    zhJudge = 180;
    tool = 10;
    postEdit = judge + zhJudge + 3 * tool;
  };

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
in
{
  inherit timeouts;
}
// import ./post-tool-use {
  inherit
    pkgs
    lib
    assistant
    mkHookScript
    repo
    timeouts
    enableDevToolchains
    ;
}
// import ./stop
