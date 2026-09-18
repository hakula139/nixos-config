# ==============================================================================
# Shared Skills
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  acpCfg = config.hakula.llm-assistants.acp;
  anthropic = inputs.anthropics-skills + "/skills";
  openai = inputs.openai-skills + "/skills/.curated";

  sources = {
    browser-debugging = ./browser-debugging;
    clean-gone = ./clean-gone;
    environment-repair = ./environment-repair;
    frontend-design = anthropic + "/frontend-design";
    gh-address-comments = openai + "/gh-address-comments";
    gh-fix-ci = openai + "/gh-fix-ci";
    git-workflow = ./git-workflow;
    mcp-builder = anthropic + "/mcp-builder";
    pr-review-toolkit = ./pr-review-toolkit;
    read-pdfs = ./read-pdfs;
    security-best-practices = openai + "/security-best-practices";
  }
  // lib.optionalAttrs acpCfg.enable {
    acp-delegate = ./acp-delegate;
  }
  // lib.optionalAttrs config.hakula.ctx7.enable {
    find-docs = "${pkgs.unstable.ctx7}/skills/find-docs";
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
    (lib.mkIf (
      config.hakula.claude-code.enable || config.hakula.cursor.enable || config.hakula.opencode.enable
    ) (mkSkillFiles ".claude/skills"))
    (lib.mkIf config.hakula.omp.enable (mkSkillFiles ".omp/agent/skills"))
  ];
}
