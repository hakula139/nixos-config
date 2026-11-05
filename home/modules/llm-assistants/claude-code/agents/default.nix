# ==================================================================================================
# Claude Code Custom Agents
# ==================================================================================================

{
  lib,
  shared,
  enabledAgents,
  efforts,
}:

let
  renderField =
    settings: field: lib.optional (settings ? ${field}) "${field}: ${toString settings.${field}}";

  renderFrontmatter =
    name: agent:
    let
      settings = agent.claude // {
        model = shared.profileDefinitions.modelAliases.claude.${agent.workload};
        effort = efforts.${agent.workload};
      };

      frontmatterLines = [
        "name: ${name}"
        "description: ${builtins.toJSON agent.description}"
      ]
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

  allAgents = lib.mapAttrs renderAgent shared.agentRoles;
in
{
  files = lib.filterAttrs (name: _: lib.elem name enabledAgents) allAgents;
}
