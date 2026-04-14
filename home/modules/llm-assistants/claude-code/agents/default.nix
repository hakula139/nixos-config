# ==============================================================================
# Claude Code Custom Agents
# ==============================================================================

{
  lib,
  enabledAgents,
  codexEnabled ? false,
}:

let
  sharedAgents = import ../../shared/agent-roles;

  renderIndentedLines =
    value: map (line: "  ${line}") (lib.filter (line: line != "") (lib.splitString "\n" value));

  renderField =
    agent: fieldSpec:
    let
      field = if builtins.isString fieldSpec then { name = fieldSpec; } else fieldSpec;
      format = field.format or toString;
    in
    lib.optional (agent.claude ? ${field.name}) "${field.name}: ${format agent.claude.${field.name}}";

  renderFrontmatter =
    name: agent:
    let
      frontmatterLines = [
        "name: ${name}"
        "description: |"
      ]
      ++ renderIndentedLines agent.description
      ++ lib.concatMap (renderField agent) [
        "color"
        "model"
        "effort"
        "permissionMode"
        "maxTurns"
        "memory"
        "isolation"
        {
          name = "background";
          format = lib.boolToString;
        }
      ]
      ++ lib.optional (
        (agent.claude.tools or [ ]) != [ ]
      ) "tools: ${lib.concatStringsSep ", " agent.claude.tools}";
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  renderAgent = name: agent: ''
    ${renderFrontmatter name agent}

    ${agent.prompt}
  '';

  allAgents =
    lib.mapAttrs renderAgent sharedAgents
    // lib.optionalAttrs codexEnabled {
      codex-worker = builtins.readFile ./codex-worker.md;
    };
in
lib.filterAttrs (name: _: lib.elem name enabledAgents) allAgents
