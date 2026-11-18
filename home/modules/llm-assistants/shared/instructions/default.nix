# ==================================================================================================
# Assistant Instruction Documents
# ==================================================================================================

{
  promptFragments,
  devkitSource ? "@devkitSource@",
  docsDir ? "@docsDir@",
}:

let
  docs = import ./docs {
    inherit promptFragments;
  };

  base = promptFragments.renderPrompt {
    "@devkitSource@" = devkitSource;
    "@docsDir@" = docsDir;
  } ./instructions.md;
in
{
  inherit base docs;
  full = builtins.concatStringsSep "\n" ([ base ] ++ builtins.attrValues docs);
}
