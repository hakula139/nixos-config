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
  skillsInstalled = cfg.enable || config.hakula.codex.enable || config.hakula.omp.enable;
  corpGateway = config.lib.llmAssistants.profileDefinitions.providers.corp-gateway;
  corpGatewayEnabled = cfg.enable && cfg.auth.enableCorpGateway;

  # ------------------------------------------------------------------------------------------------
  # Skill sources
  # ------------------------------------------------------------------------------------------------
  plugins = inputs.plugins.lib.skills;
  promptFragments = import ../prompt-fragments;

  sources =
    lib.removeAttrs plugins [
      "acp-delegate"
      "find-docs"
    ]
    // {
      model-track-record = ./model-track-record;
    }
    // lib.optionalAttrs config.hakula.acp.enable {
      inherit (plugins) acp-delegate;
    }
    // lib.optionalAttrs config.hakula.activity-report.enable {
      activity-report = ./activity-report;
    }
    // lib.optionalAttrs config.hakula.agent-project-move.enable {
      agent-project-move = "${config.programs.agent-project-move.package}/share/skills/agent-project-move";
    }
    // lib.optionalAttrs config.hakula.ctx7.enable {
      inherit (plugins) find-docs;
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
          # Leaves a full batch's rewrite headroom past the hooks' model-call limit.
          timeout = 300;
        };
      };
    };

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
    (lib.mkIf cfg.enable (mkSkillFiles {
      directory = ".claude/skills";
      recursive = true;
    }))
    (lib.mkIf config.hakula.omp.enable (mkSkillFiles {
      directory = ".omp/agent/skills";
      recursive = true;
    }))
  ];

  home.packages = lib.mkIf skillsInstalled [ pkgs.clean-gone ];

  hakula.secrets.required = lib.mkIf corpGatewayEnabled {
    ${corpGateway.tokenSecretFor "prose-polish"} = { };
    ${corpGateway.caSecret} = { };
  };
}
