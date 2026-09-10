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

  # OpenCode shares Claude's directory. Cursor can disable third-party skill
  # discovery, so install its skills in the native directory.
  targets =
    lib.optional (config.hakula.claude-code.enable || config.hakula.opencode.enable) ".claude/skills"
    ++ lib.optional (
      config.hakula.cursor.enable || (acpCfg.enable && acpCfg.cursor.enable)
    ) ".cursor/skills";

  mkSkillFiles =
    dir:
    lib.mapAttrs' (
      name: source:
      lib.nameValuePair "${dir}/${name}" {
        inherit source;
        recursive = true;
      }
    ) sources;
in
{
  lib.llmAssistants.skills = sources;

  home.file = lib.mkMerge (map mkSkillFiles targets);
}
