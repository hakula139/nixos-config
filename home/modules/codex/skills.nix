{
  lib,
  inputs,
  ...
}:

# ==============================================================================
# Codex Skills
# ==============================================================================

let
  skillsSrc = inputs.agent-skills;
  mkSkill = name: "${skillsSrc}/skills/${name}";

  # ----------------------------------------------------------------------------
  # Enabled skills
  # ----------------------------------------------------------------------------
  enabledSkills = {
    # Document format processing (document-skills@anthropic-agent-skills)
    docx = mkSkill "docx";
    pdf = mkSkill "pdf";
    pptx = mkSkill "pptx";
    xlsx = mkSkill "xlsx";

    # General capabilities (example-skills@anthropic-agent-skills)
    algorithmic-art = mkSkill "algorithmic-art";
    brand-guidelines = mkSkill "brand-guidelines";
    canvas-design = mkSkill "canvas-design";
    doc-coauthoring = mkSkill "doc-coauthoring";
    frontend-design = mkSkill "frontend-design";
    internal-comms = mkSkill "internal-comms";
    mcp-builder = mkSkill "mcp-builder";
    skill-creator = mkSkill "skill-creator";
    slack-gif-creator = mkSkill "slack-gif-creator";
    theme-factory = mkSkill "theme-factory";
    web-artifacts-builder = mkSkill "web-artifacts-builder";
    webapp-testing = mkSkill "webapp-testing";
  };
in
{
  inherit enabledSkills;

  # ----------------------------------------------------------------------------
  # Activation script
  # ----------------------------------------------------------------------------
  activation = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    skillsDir="$HOME/.agents/skills"
    install -d "$skillsDir"

    # Remove stale symlinks
    for entry in "$skillsDir"/*; do
      [[ -L "$entry" ]] && rm "$entry"
    done

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: src: ''
        # Remove residual directory from previous home.file management
        [[ -d "$skillsDir/${name}" ]] && rm -rf "$skillsDir/${name}"
        ln -sfn ${lib.escapeShellArg (toString src)} "$skillsDir/${name}"
      '') enabledSkills
    )}
  '';
}
