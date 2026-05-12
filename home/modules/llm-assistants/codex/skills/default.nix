# ==============================================================================
# Codex Skills
# ==============================================================================

{
  lib,
  inputs,
  ...
}:

let
  skills = import ../../shared/skills {
    inherit lib inputs;
    localCodexSkills = ./local;
  };
in
{
  settings = {
    bundled.enabled = true;
  };

  homeFiles = skills.mkSkillHomeFiles ".agents/skills" skills.codexSkills;
}
