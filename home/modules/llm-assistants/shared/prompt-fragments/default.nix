# ==============================================================================
# Shared Prompt Fragments
# ==============================================================================

let
  fragments = builtins.mapAttrs (_: builtins.readFile) {
    "@preamble@" = ./preamble.md;

    "@comments@" = ./comments.md;
    "@phrasing@" = ./phrasing.md;
    "@proseTics@" = ./prose-tics.md;

    "@memory@" = ./memory.md;
    "@coordination@" = ./coordination.md;
  };
  placeholders = builtins.attrNames fragments;
  fragmentBodies = builtins.attrValues fragments;
in
{
  readPrompt = file: builtins.replaceStrings placeholders fragmentBodies (builtins.readFile file);
  phrasing = fragments."@phrasing@";
}
