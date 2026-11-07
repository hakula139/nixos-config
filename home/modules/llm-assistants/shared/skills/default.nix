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
  corpGateway = config.lib.llmAssistants.profileDefinitions.providers.corp-gateway;
  corpGatewayEnabled = cfg.auth.enableCorpGateway;

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

  # ------------------------------------------------------------------------------------------------
  # Skill files
  # ------------------------------------------------------------------------------------------------
  mkSkillFiles =
    { directory, recursive }:
    lib.mapAttrs' (
      name: source: lib.nameValuePair "${directory}/${name}" { inherit source recursive; }
    ) sources;
in
lib.mkIf cfg.enable {
  # ------------------------------------------------------------------------------------------------
  # Skills
  # ------------------------------------------------------------------------------------------------
  home.file = lib.mkMerge [
    (mkSkillFiles {
      directory = "${config.lib.llmAssistants.claudeConfigDir}/skills";
      recursive = true;
    })
    (mkSkillFiles {
      directory = "${config.lib.llmAssistants.ompConfigDir}/skills";
      recursive = true;
    })
    (mkSkillFiles {
      directory = "${config.lib.llmAssistants.codexConfigDir}/skills";
      recursive = false;
    })
  ];

  # ------------------------------------------------------------------------------------------------
  # Helper programs
  # ------------------------------------------------------------------------------------------------
  hakula.activity-report.enable = true;
  hakula.agent-project-move.enable = true;

  # ------------------------------------------------------------------------------------------------
  # Secrets
  # ------------------------------------------------------------------------------------------------
  hakula.secrets.required = lib.mkIf corpGatewayEnabled {
    ${corpGateway.tokenSecretFor "prose-polish"} = { };
    ${corpGateway.caSecret} = { };
  };
}
