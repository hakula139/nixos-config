# ==============================================================================
# Shared Instruction Documents
# ==============================================================================

let
  fragments = {
    "@comments@" = ./comments.md;
    "@phrasing@" = ./phrasing.md;
    "@proseTics@" = ./prose-tics.md;
    "@proseTicsZh@" = ./prose-tics-zh.md;
  };

  compose =
    file:
    builtins.replaceStrings (builtins.attrNames fragments) (map builtins.readFile (
      builtins.attrValues fragments
    )) (builtins.readFile file);

  sharedBody = compose ./shared.md;

  render =
    {
      title,
      intro,
      body,
    }:
    builtins.concatStringsSep "\n\n" [
      "# ${title}"
      intro
      sharedBody
      (builtins.readFile body)
    ];
in
{
  claudeCode = render {
    title = "CLAUDE.md";
    intro = "Global instructions for Claude Code behavior across all projects.";
    body = ./claude-code.md;
  };

  codex = render {
    title = "AGENTS.md";
    intro = "Global instructions for Codex behavior across all projects.";
    body = ./agents.md;
  };

  opencode = render {
    title = "AGENTS.md";
    intro = "Global instructions for OpenCode behavior across all projects.";
    body = ./agents.md;
  };

  # `prose-polish` takes `phrasing.md` alone, since a rule checklist measured
  # worst of the five frames tested as a rewrite prompt.
  commentGate = compose ./comment-gate.md;
}
