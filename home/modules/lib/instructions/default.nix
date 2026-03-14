let
  sharedBody = builtins.readFile ./shared.md;
  claudeBody = builtins.readFile ./claude-code.md;
  codexBody = builtins.readFile ./codex.md;

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
      body
    ];
in
{
  claudeCode = render {
    title = "CLAUDE.md";
    intro = "Global instructions for Claude Code behavior across all projects.";
    body = claudeBody;
  };

  codex = render {
    title = "AGENTS.md";
    intro = "Global instructions for Codex behavior across all projects.";
    body = codexBody;
  };
}
