# ==============================================================================
# Comment Gate Hook
# ==============================================================================

{
  mkNuHook,
  modelCall,
  instructionsDir,
}:

let
  promptFragments = {
    "@comments@" = "${instructionsDir}/comments.md";
    "@proseTics@" = "${instructionsDir}/prose-tics.md";
    "@proseTicsZh@" = "${instructionsDir}/prose-tics-zh.md";
  };

  prompt = builtins.replaceStrings (builtins.attrNames promptFragments) (map builtins.readFile (
    builtins.attrValues promptFragments
  )) (builtins.readFile ./comment-gate-prompt.md);
in
{
  inherit prompt;

  commentGate = mkNuHook {
    slug = "comment-gate";
    script = ./comment-gate.nu;
    config = {
      inherit modelCall prompt;
    };
  };
}
