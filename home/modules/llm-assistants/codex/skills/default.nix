# ==============================================================================
# Codex Skills
# ==============================================================================

{
  pkgs,
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
    gh-address-comments = sources.openai + "/gh-address-comments";
    gh-fix-ci = sources.openai + "/gh-fix-ci";
    security-best-practices = sources.openai + "/security-best-practices";

    frontend-design = sources.anthropic + "/frontend-design";
    mcp-builder = sources.anthropic + "/mcp-builder";
    webapp-testing = sources.anthropic + "/webapp-testing";

    pr-draft-summary = ./pr-draft-summary;
    pr-review-toolkit = ./pr-review-toolkit;
  };

  bundle = pkgs.linkFarm "codex-skills" (
    lib.mapAttrsToList (name: path: { inherit name path; }) skills
  );
in
{
  settings = {
    bundled.enabled = true;
  };

  homeFile = {
    ".agents/skills" = {
      source = bundle;
      recursive = true;
    };
  };
}
