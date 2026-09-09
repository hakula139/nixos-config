# ==============================================================================
# Shared Skills
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  sources = {
    browser-debugging = ./browser-debugging;
    git-workflow = ./git-workflow;
  };
in
{
  lib.llmAssistants.skills = sources;

  # Cursor and OpenCode discover Claude's directory, so install shared skills once.
  home.file =
    lib.mkIf
      (config.hakula.claude-code.enable || config.hakula.cursor.enable || config.hakula.opencode.enable)
      (
        lib.mapAttrs' (
          name: source:
          lib.nameValuePair ".claude/skills/${name}" {
            inherit source;
            recursive = true;
          }
        ) sources
      );
}
