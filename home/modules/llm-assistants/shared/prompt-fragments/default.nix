# ==================================================================================================
# Shared Prompt Fragments
# ==================================================================================================

let
  fragments = builtins.mapAttrs (_: builtins.readFile) {
    "@preamble@\n" = ./preamble.md;

    "@comments@\n" = ./comments.md;
    "@phrasing@\n" = ./phrasing.md;
    "@proseTics@\n" = ./prose-tics.md;

    "@readOnly@\n" = ./read-only.md;
  };

  renderPrompt =
    extra: file:
    let
      merged = fragments // extra;
    in
    builtins.replaceStrings (builtins.attrNames merged) (builtins.attrValues merged) (
      builtins.readFile file
    );
in
{
  inherit renderPrompt;

  readPrompt = renderPrompt { };
  phrasing = fragments."@phrasing@\n";

  roleSections = {
    memory = builtins.readFile ./memory.md;
    coordination = builtins.readFile ./coordination.md;
    status = builtins.readFile ./status.md;
  };
}
