# ==============================================================================
# Shared Agent Skills
# ==============================================================================

{
  lib,
  inputs,
  localCodexSkills ? null,
  ...
}:

let
  catalogs = {
    anthropic = inputs.anthropics-skills + "/skills";
    openai = inputs.openai-skills + "/skills/.curated";
  }
  // lib.optionalAttrs (localCodexSkills != null) {
    localCodex = localCodexSkills;
  };

  mkSkillHomeFiles =
    targetDir: skills:
    lib.mapAttrs' (
      name: source:
      lib.nameValuePair "${targetDir}/${name}" {
        inherit source;
      }
    ) skills;

  codexSkills = {
    # OpenAI-maintained Codex skills.
    gh-address-comments = catalogs.openai + "/gh-address-comments";
    gh-fix-ci = catalogs.openai + "/gh-fix-ci";
    security-best-practices = catalogs.openai + "/security-best-practices";

    # Generic Anthropic Agent Skills that follow the open skill format.
    frontend-design = catalogs.anthropic + "/frontend-design";
    mcp-builder = catalogs.anthropic + "/mcp-builder";
    webapp-testing = catalogs.anthropic + "/webapp-testing";
  }
  // lib.optionalAttrs (localCodexSkills != null) {
    pr-draft-summary = catalogs.localCodex + "/pr-draft-summary";
    pr-review-toolkit = catalogs.localCodex + "/pr-review-toolkit";
  };
in
{
  inherit
    catalogs
    codexSkills
    mkSkillHomeFiles
    ;
}
