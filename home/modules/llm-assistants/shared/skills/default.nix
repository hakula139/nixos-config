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

  mkSkillFiles =
    directory:
    lib.mapAttrs' (
      name: source:
      lib.nameValuePair "${directory}/${name}" {
        inherit source;
        recursive = true;
      }
    ) sources;
in
{
  lib.llmAssistants.skills = sources;

  home.file = lib.mkMerge [
    # Cursor and OpenCode discover Claude's directory, so install shared skills once.
    (lib.mkIf (
      config.hakula.claude-code.enable || config.hakula.cursor.enable || config.hakula.opencode.enable
    ) (mkSkillFiles ".claude/skills"))
    (lib.mkIf config.hakula.omp.enable (mkSkillFiles ".omp/agent/skills"))
  ];
}
