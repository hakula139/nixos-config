# ==================================================================================================
# Shared Skills
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  modelCatalog,
  repoLib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
  claudeSkillsInstalled =
    cfg.enable || config.hakula.claude-code.enable || config.hakula.opencode.enable;
  skillsInstalled = claudeSkillsInstalled || config.hakula.codex.enable || config.hakula.omp.enable;
  corpGateway = config.lib.llmAssistants.profileDefinitions.providers.corp-gateway;
  corpGatewayEnabled = cfg.enable && cfg.auth.enableCorpGateway;

  # ------------------------------------------------------------------------------------------------
  # Skill sources
  # ------------------------------------------------------------------------------------------------
  pluginSkills = inputs.plugins.lib.skills;
  promptFragments = import ../prompt-fragments;

  hostSkills = {
    activity-report = ./activity-report;
    agent-project-move = "${config.programs.agent-project-move.package}/share/skills/agent-project-move";
  }
  // lib.optionalAttrs corpGatewayEnabled {
    prose-polish = import ./prose-polish {
      inherit
        pkgs
        lib
        modelCatalog
        promptFragments
        repoLib
        ;
      modelCall = config.lib.llmAssistants.mkModelCall {
        assistant = "prose-polish";
        timeout = 300;
      };
    };
  };

  sources = lib.attrsets.unionOfDisjoint pluginSkills hostSkills;

  mkSkillFiles =
    { directory, recursive }:
    lib.mapAttrs' (
      name: source: lib.nameValuePair "${directory}/${name}" { inherit source recursive; }
    ) sources;
in
{
  lib.llmAssistants = { inherit mkSkillFiles; };

  # Cursor and OpenCode discover Claude's directory, so install shared skills once.
  home.file = lib.mkMerge [
    (lib.mkIf claudeSkillsInstalled (mkSkillFiles {
      directory = ".claude/skills";
      recursive = true;
    }))
    (lib.mkIf config.hakula.omp.enable (mkSkillFiles {
      directory = ".omp/agent/skills";
      recursive = true;
    }))
  ];

  home.packages = lib.mkIf skillsInstalled [ pkgs.clean-gone ];

  hakula.activity-report.enable = lib.mkIf skillsInstalled (lib.mkDefault true);
  hakula.agent-project-move.enable = lib.mkIf skillsInstalled (lib.mkDefault true);

  hakula.secrets.required = lib.mkIf corpGatewayEnabled {
    ${corpGateway.tokenSecretFor "prose-polish"} = { };
    ${corpGateway.caSecret} = { };
  };
}
