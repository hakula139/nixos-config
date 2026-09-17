# ==============================================================================
# OMP Custom Agents
# ==============================================================================

{
  lib,
  sharedAgents,
  enabledAgents,
  modelAliases,
}:

let
  renderFrontmatter =
    name: agent:
    let
      frontmatterLines = [
        "name: ${builtins.toJSON name}"
        "description: ${builtins.toJSON agent.description}"
        "model: ${builtins.toJSON "@${modelAliases.${agent.modelTier}}:${agent.effort}"}"
      ]
      ++ lib.optional (agent.omp ? spawns) "spawns: ${builtins.toJSON agent.omp.spawns}"
      ++ lib.optional (agent.omp ? tools) "tools: ${lib.concatStringsSep ", " agent.omp.tools}";
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  renderAgent = name: agent: ''
    ${renderFrontmatter name agent}

    ${agent.prompt}
  '';
in
{
  homeFiles = lib.mapAttrs' (
    name: agent: lib.nameValuePair ".omp/agent/agents/${name}.md" { text = renderAgent name agent; }
  ) (lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents);
}
