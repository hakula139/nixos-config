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
    git-workflow = ./git-workflow;
  };
in
{
  lib.llmAssistants.skills = sources;

  # OpenCode also discovers Claude's directory, so install shared skills once.
  home.file = lib.mkIf (config.hakula.claude-code.enable || config.hakula.opencode.enable) (
    lib.mapAttrs' (
      name: source:
      lib.nameValuePair ".claude/skills/${name}" {
        inherit source;
        recursive = true;
      }
    ) sources
  );
}
