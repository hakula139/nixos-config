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
  promptFragments = import ../prompt-fragments;

  anthropic = inputs.anthropics-skills + "/skills";

  sources = {
    ast-grep = ./ast-grep;
    browser-debugging = ./browser-debugging;
    clean-gone = ./clean-gone;
    code-layout = ./code-layout;
    cspell = ./cspell;
    disk-cleanup = ./disk-cleanup;
    dream = ./dream;
    environment-repair = ./environment-repair;
    frontend-design = anthropic + "/frontend-design";
    git-workflow = ./git-workflow;
    mcp-builder = anthropic + "/mcp-builder";
    model-delegation = ./model-delegation;
    nix = ./nix;
    nushell = ./nushell;
    read-pdfs = ./read-pdfs;
    review = ./review;
  }
  // lib.optionalAttrs config.hakula.acp.enable {
    acp-delegate = ./acp-delegate;
  }
  // lib.optionalAttrs config.hakula.activity-report.enable {
    activity-report = ./activity-report;
  }
  // lib.optionalAttrs config.hakula.agent-project-move.enable {
    agent-project-move = "${config.programs.agent-project-move.package}/share/skills/agent-project-move";
  }
  // lib.optionalAttrs config.hakula.ctx7.enable {
    find-docs = ./find-docs;
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
      modelCall = config.lib.llmAssistants.mkModelCall "prose-polish";
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
