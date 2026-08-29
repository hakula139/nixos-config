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
  # Prose doctrine
  # ----------------------------------------------------------------------------
  instructions = builtins.readFile ../instructions/shared.md;

  section =
    name:
    "## ${name}\n"
    + lib.head (lib.splitString "\n## " (lib.elemAt (lib.splitString "\n## ${name}\n" instructions) 1))
    + "\n";

  proseDoctrine = pkgs.writeText "prose-doctrine.md" (section "Phrasing");

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
    enableDevToolchains
    mkHookScript
    repo
    timeouts
    ;
}
// import ./pre-tool-use {
  inherit
    pkgs
    lib
    mkHookScript
    proseDoctrine
    timeouts
    ;
}
// import ./stop
