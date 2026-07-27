# ==============================================================================
# Codex Skills
# ==============================================================================

{
  lib,
  inputs,
  ...
}:

let
  sources = {
    anthropic = inputs.anthropics-skills + "/skills";
    openai = inputs.openai-skills + "/skills/.curated";
  };

  skills = {
    # OpenAI Codex skills
    gh-address-comments = sources.openai + "/gh-address-comments";
    gh-fix-ci = sources.openai + "/gh-fix-ci";
    security-best-practices = sources.openai + "/security-best-practices";

    # Anthropic skills
    frontend-design = sources.anthropic + "/frontend-design";
    mcp-builder = sources.anthropic + "/mcp-builder";
    webapp-testing = sources.anthropic + "/webapp-testing";

    # Local skills
    clean-gone = ./clean-gone;
    pr-draft-summary = ./pr-draft-summary;
    pr-review-toolkit = ./pr-review-toolkit;
    read-pdfs = ./read-pdfs;
  };
in
{
  settings = {
    bundled.enabled = true;
  };

  homeFile = lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".agents/skills/${name}" {
      inherit source;
      recursive = true;
    }
  ) skills;
}
