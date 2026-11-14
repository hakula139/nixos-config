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

  localSkills = lib.optionalAttrs corpGatewayEnabled {
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

  hostSkills = localSkills // {
    activity-report = "${config.programs.activity-report.package}/share/skills/activity-report";
    agent-project-move = "${config.programs.agent-project-move.package}/share/skills/agent-project-move";
  };

  sources = lib.attrsets.unionOfDisjoint pluginSkills hostSkills;

  # ------------------------------------------------------------------------------------------------
  # Skill scripts
  # ------------------------------------------------------------------------------------------------
  # Only skills this repository owns contribute permission rules, so an input bump cannot silently
  # add allows for scripts this repository does not review. A built skill declares its scripts
  # through `passthru.scripts`.
  skillScripts = lib.optionals cfg.enable (
    lib.concatLists (
      lib.mapAttrsToList (
        skill: source: map (file: { inherit skill file; }) (source.scripts or [ ])
      ) localSkills
    )
  );

  mkSkillScriptPaths =
    skillsDir: map (script: "${skillsDir}/${script.skill}/${script.file}") skillScripts;

  # ------------------------------------------------------------------------------------------------
  # Skill files
  # ------------------------------------------------------------------------------------------------
  mkSkillFiles =
    { directory, recursive }:
    lib.mapAttrs' (
      name: source: lib.nameValuePair "${directory}/${name}" { inherit source recursive; }
    ) sources;
in
lib.mkMerge [
  {
    lib.llmAssistants = {
      inherit mkSkillScriptPaths;
    };
  }

  (lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Skills
    # ----------------------------------------------------------------------------------------------
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

    # ----------------------------------------------------------------------------------------------
    # Helper programs
    # ----------------------------------------------------------------------------------------------
    hakula.activity-report.enable = true;
    hakula.agent-project-move.enable = true;

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.mkIf corpGatewayEnabled {
      ${corpGateway.tokenSecretFor "prose-polish"} = { };
      ${corpGateway.caSecret} = { };
    };
  })
]
