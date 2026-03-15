{
  lib,
  enabledAgents,
  codexEnabled ? false,
}:

# ==============================================================================
# Claude Code Custom Agents
# ==============================================================================

let
  sharedAgents = import ../../shared/agent-roles;

  renderIndentedLines =
    value: map (line: "  ${line}") (lib.filter (line: line != "") (lib.splitString "\n" value));

  renderFrontmatter =
    name: agent:
    let
      frontmatterLines = [
        "name: ${name}"
        "description: |"
      ]
      ++ renderIndentedLines agent.description
      ++ lib.optional (agent.claude ? color) "color: ${agent.claude.color}"
      ++ lib.optional (agent.claude ? model) "model: ${agent.claude.model}"
      ++ lib.optionals ((agent.claude.tools or [ ]) != [ ]) (
        [ "tools:" ] ++ map (tool: "  - ${tool}") agent.claude.tools
      );
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
