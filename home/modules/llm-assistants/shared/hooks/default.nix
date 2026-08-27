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
    # The judge writes out its scan before the verdict, so a call costs about 28s
    # of which 22s is API time. At 30s it raced its own timeout and failed open on
    # roughly half of all invocations.
    judge = 90;
    zhPolish = 90;
    tool = 10;
    postEdit = judge + zhPolish + 3 * tool;
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
