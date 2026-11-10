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

  localSkills = {
    activity-report = ./activity-report;
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

  hostSkills = localSkills // {
    agent-project-move = "${config.programs.agent-project-move.package}/share/skills/agent-project-move";
  };

  sources = lib.attrsets.unionOfDisjoint pluginSkills hostSkills;

  # ------------------------------------------------------------------------------------------------
  # Skill scripts
  # ------------------------------------------------------------------------------------------------
  skippedScript =
    name:
    lib.any (suffix: lib.hasSuffix suffix name) [
      ".test.nu"
      ".stub.nu"
    ];

  scriptsFrom =
    source:
    if lib.isAttrs source && source ? passthru.entries then
      builtins.filter (lib.hasPrefix "scripts/") (builtins.attrNames source.passthru.entries)
    else if lib.pathExists (source + "/scripts") then
      map (name: "scripts/${name}") (
        builtins.attrNames (
          lib.filterAttrs (name: type: type == "regular" && !skippedScript name) (
            builtins.readDir (source + "/scripts")
          )
        )
      )
    else
      [ ];

  # Only skills this repository owns contribute permission rules, so an input bump cannot silently
  # add allows for scripts this repository does not review.
  skillScripts = lib.concatLists (
    lib.mapAttrsToList (
      skill: source: map (file: { inherit skill file; }) (scriptsFrom source)
    ) localSkills
  );

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
    lib.llmAssistants.skillScripts = skillScripts;
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
