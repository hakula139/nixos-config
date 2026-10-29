# ==================================================================================================
# OpenCode Custom Agents
# ==================================================================================================

{
  lib,
  sharedAgents,
  enabledAgents,
}:

let
  renderFrontmatter =
    agent:
    let
      permission = agent.opencode.permission or { };
      frontmatterLines = [
        "description: ${builtins.toJSON agent.description}"
        "mode: subagent"
      ]
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
