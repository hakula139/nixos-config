# ==============================================================================
# Assistant Instruction Documents
# ==============================================================================

{
  readPrompt,
}:

let
  sharedBody = readPrompt ./shared.md;

  render =
    {
      title,
      intro,
      body ? null,
    }:
    builtins.concatStringsSep "\n\n" (
      [
        "# ${title}"
        intro
        sharedBody
      ]
      ++ (if body == null then [ ] else [ (builtins.readFile body) ])
    );
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
  };

  omp = render {
    title = "AGENTS.md";
    intro = "Global instructions for OMP behavior across all projects.";
  };

  opencode = render {
    title = "AGENTS.md";
    intro = "Global instructions for OpenCode behavior across all projects.";
  };
}
