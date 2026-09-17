# ==============================================================================
# OpenCode Custom Agents
# ==============================================================================

{
  lib,
  sharedAgents,
  enabledAgents,
}:

let
  renderIndentedLines =
    value: map (line: "  ${line}") (lib.filter (line: line != "") (lib.splitString "\n" value));

  renderFrontmatter =
    agent:
    let
      permission = agent.opencode.permission or { };
      frontmatterLines = [
        "description: |"
      ]
      ++ renderIndentedLines agent.description
      ++ [ "mode: subagent" ]
      ++ lib.optionals (permission != { }) (
        [ "permission:" ]
        ++ lib.mapAttrsToList (name: value: "  ${name}: ${builtins.toJSON value}") permission
      );
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  renderAgent = _name: agent: ''
    ${renderFrontmatter agent}

    ${agent.prompt}
  '';
in
lib.mapAttrs renderAgent (lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents)
