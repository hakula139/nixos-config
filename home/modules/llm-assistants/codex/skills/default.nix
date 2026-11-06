# ==================================================================================================
# Codex Skills
# ==================================================================================================

{
  shared,
  skillsDir,
}:

{
  files = shared.mkSkillFiles {
    directory = skillsDir;
    recursive = false;
  };

  settings = {
    bundled.enabled = true;
  };
}
