# ==============================================================================
# Shared Skills
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  acpCfg = config.hakula.llm-assistants.acp;

  sources = {
    browser-debugging = ./browser-debugging;
    git-workflow = ./git-workflow;
  }
  // lib.optionalAttrs acpCfg.enable {
    acp-delegate = ./acp-delegate;
  };
in
{
  lib.llmAssistants.skills = sources;

  # Cursor and OpenCode discover Claude's directory, so install shared skills once.
  home.file =
    lib.mkIf
      (
        config.hakula.claude-code.enable
        || config.hakula.cursor.enable
        || config.hakula.opencode.enable
        || (acpCfg.enable && acpCfg.cursor.enable)
      )
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
