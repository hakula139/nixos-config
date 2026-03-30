# ==============================================================================
# OpenCode Custom Agents
# ==============================================================================

{
  lib,
  enabledAgents,
}:

let
  sharedAgents = import ../shared/agent-roles;

  renderIndentedLines =
    value: map (line: "  ${line}") (lib.filter (line: line != "") (lib.splitString "\n" value));

  renderFrontmatter =
    agent:
    let
      oc = agent.opencode or { };
      tools = oc.tools or { };
      frontmatterLines = [
        "description: |"
      ]
      ++ renderIndentedLines agent.description
      ++ [ "mode: subagent" ]
      ++ lib.optionals (tools != { }) (
        [ "tools:" ] ++ lib.mapAttrsToList (k: v: "  ${k}: ${lib.boolToString v}") tools
      );
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  renderAgent = _name: agent: ''
    ${renderFrontmatter agent}

    ${agent.prompt}
  '';
in
lib.mapAttrs renderAgent (lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents)
