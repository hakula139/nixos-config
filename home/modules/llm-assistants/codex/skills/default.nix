# ==============================================================================
# Codex Skills
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  llmAssistantSkills,
  configDir,
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
    pr-review-toolkit = ./pr-review-toolkit;
    read-pdfs = ./read-pdfs;
  };

  managedSkills = lib.filterAttrs (
    _: file: file.enable && lib.hasPrefix ".agents/skills/" file.target
  ) config.home.file;

  skillBundle = pkgs.linkFarm "codex-managed-skills" (
    lib.mapAttrsToList (_: file: {
      name = lib.removePrefix ".agents/skills/" file.target;
      path = file.source;
    }) managedSkills
    ++ lib.mapAttrsToList (name: path: { inherit name path; }) llmAssistantSkills
  );
in
{
  # Codex 0.153.4 skips Home Manager's symlinked skills during discovery.
  activation = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -d -m 0700 ${lib.escapeShellArg "${configDir}/skills/nixos-config"}
    run ${pkgs.rsync}/bin/rsync -rpL --delete --chmod=u=rwX,go= \
      ${skillBundle}/ ${lib.escapeShellArg "${configDir}/skills/nixos-config/"}
  '';

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
