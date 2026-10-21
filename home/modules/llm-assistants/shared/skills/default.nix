# ==================================================================================================
# Shared Skills
# ==================================================================================================

{
  config,
  lib,
  inputs,
  ...
}:

let
  anthropic = inputs.anthropics-skills + "/skills";
  openai = inputs.openai-skills + "/skills/.curated";

  sources = {
    ast-grep = ./ast-grep;
    browser-debugging = ./browser-debugging;
    clean-gone = ./clean-gone;
    cspell = ./cspell;
    disk-cleanup = ./disk-cleanup;
    dream = ./dream;
    environment-repair = ./environment-repair;
    frontend-design = anthropic + "/frontend-design";
    gh-address-comments = openai + "/gh-address-comments";
    gh-fix-ci = openai + "/gh-fix-ci";
    git-workflow = ./git-workflow;
    mcp-builder = anthropic + "/mcp-builder";
    model-delegation = ./model-delegation;
    read-pdfs = ./read-pdfs;
    review = ./review;
    security-best-practices = openai + "/security-best-practices";
  }
  // lib.optionalAttrs config.hakula.acp.enable {
    acp-delegate = ./acp-delegate;
  }
  // lib.optionalAttrs config.hakula.activity-report.enable {
    activity-report = ./activity-report;
  }
  // lib.optionalAttrs config.hakula.ctx7.enable {
    find-docs = ./find-docs;
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
    (lib.mkIf config.hakula.llm-assistants.enable (mkSkillFiles ".claude/skills"))
    (lib.mkIf config.hakula.omp.enable (mkSkillFiles ".omp/agent/skills"))
  ];
}
