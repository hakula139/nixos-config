# ==================================================================================================
# Shared Skills
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  anthropic = inputs.anthropics-skills + "/skills";
  openai = inputs.openai-skills + "/skills/.curated";

  # The managed `ctx7` command loads its API key at launch, so drop the skill's npx, global install,
  # and login steps.
  ctx7Install = ''
    Optionally install globally if you prefer a bare `ctx7` command:

    ```bash
    npm install -g ctx7@latest
    ```

  '';
  ctx7Auth = ''
    ## Authentication

    Works without authentication. For higher rate limits:

    ```bash
    # Option A: environment variable
    export CONTEXT7_API_KEY=your_key

    # Option B: OAuth login
    npx ctx7@latest login
    ```

  '';
  findDocs = pkgs.runCommand "find-docs-skill" { } ''
    cp -r ${pkgs.unstable.ctx7}/share/skills/ctx7/find-docs $out
    chmod -R u+w $out
    substituteInPlace $out/SKILL.md \
      --replace-fail ' so setup always uses the latest CLI without a global install' "" \
      --replace-fail ${lib.escapeShellArg ctx7Install} "" \
      --replace-fail ${lib.escapeShellArg ctx7Auth} "" \
      --replace-fail 'npx ctx7@latest' ctx7
  '';

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
    find-docs = findDocs;
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
