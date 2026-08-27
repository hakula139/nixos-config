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
    postEdit = modelCall + 3 * tool;
  };

  # ----------------------------------------------------------------------------
  # Style doctrine
  # ----------------------------------------------------------------------------
  # Sliced out of the instructions the assistant already follows, so a rule cannot
  # be restated in a gate and drift from the version being enforced on the writer.
  instructions = builtins.readFile ../instructions/shared.md;

  # The body under a `## ` heading, up to whichever heading follows it.
  section =
    name:
    "## ${name}\n"
    + lib.head (lib.splitString "\n## " (lib.elemAt (lib.splitString "\n## ${name}\n" instructions) 1))
    + "\n";

  proseDoctrine = section "Phrasing" + section "Punctuation" + section "Commenting Guidelines";
  zhDoctrine = pkgs.writeText "zh-doctrine.md" (section "Response Length" + section "Phrasing");

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
    let
      text =
        builtins.replaceStrings (builtins.attrNames substitutions) (builtins.attrValues substitutions)
          (builtins.readFile script);
      # A placeholder no substitution covers leaves a hook that still parses and
      # silently does nothing on every channel, so catch it at eval instead.
      unsubstituted = lib.filter (line: builtins.match ".*@[a-zA-Z][a-zA-Z0-9]*@.*" line != null) (
        lib.splitString "\n" text
      );
    in
    assert unsubstituted == [ ] || throw "${slug}: unsubstituted ${lib.head unsubstituted}";
    writer "${assistant}-${slug}" text;
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
    proseDoctrine
    repo
    timeouts
    ;
}
// import ./pre-tool-use {
  inherit
    pkgs
    lib
    mkHookScript
    timeouts
    zhDoctrine
    ;
}
// import ./stop
