# ==============================================================================
# Claude Code Custom Agents
# ==============================================================================

{
  lib,
  commentGate,
  enabledAgents,
  sharedAgents,
}:

let
  modelAliases = {
    flagship = "opus";
    standard = "sonnet";
    mini = "haiku";
  };

  renderIndentedLines =
    value: map (line: "  ${line}") (lib.filter (line: line != "") (lib.splitString "\n" value));

  renderField =
    settings: field: lib.optional (settings ? ${field}) "${field}: ${toString settings.${field}}";

  mkSettings =
    family: agent:
    agent.claude
    // lib.optionalAttrs (agent ? modelTier) {
      model = modelAliases.${agent.modelTier};
      effort = agent.effort.${family};
    };

  renderFrontmatter =
    name: agent:
    let
      settings = mkSettings "claude" agent;
      frontmatterLines = [
        "name: ${name}"
        "description: |"
      ]
      ++ renderIndentedLines agent.description
      ++ lib.concatMap (renderField settings) [
        "color"
        "model"
        "effort"
        "permissionMode"
        "maxTurns"
        "memory"
        "isolation"
      ]
      ++ lib.optional (settings ? background) "background: ${lib.boolToString settings.background}"
      ++ lib.optional (settings ? tools) "tools: ${lib.concatStringsSep ", " settings.tools}";
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  renderAgent = name: agent: ''
    ${renderFrontmatter name agent}

    ${agent.prompt}
  '';

  allAgents = lib.mapAttrs renderAgent sharedAgents // {
    codex-worker = builtins.readFile ./codex-worker.md;
    comment-gate = renderAgent "comment-gate" {
      description = ''
        Reviews comments and docstrings for useful rationale, clear contracts, and grounded prose
        issues. Use to review a file or diff against the shared comment guidance.
      '';
      prompt = commentGate;
      claude = {
        color = "gray";
        model = "sonnet";
        permissionMode = "plan";
      };
    };
  };
in
{
  files = lib.filterAttrs (name: _: lib.elem name enabledAgents) allAgents;

  mkProfileAgents =
    family:
    lib.mapAttrs (
      _: agent:
      mkSettings family agent
      // {
        inherit (agent) description prompt;
      }
    ) (lib.filterAttrs (name: agent: lib.elem name enabledAgents && agent ? modelTier) sharedAgents);
}
