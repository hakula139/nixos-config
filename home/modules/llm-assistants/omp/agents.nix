# ==================================================================================================
# OMP Custom Agents
# ==================================================================================================

{
  lib,
  instructions,
  sharedAgents,
  enabledAgents,
}:

let
  renderFrontmatter =
    name: agent:
    let
      omp = agent.omp or { };
      frontmatterLines = [
        "name: ${builtins.toJSON name}"
        "description: ${builtins.toJSON agent.description}"
        "model: ${builtins.toJSON "@${agent.workload}"}"
      ]
      ++ lib.optional (omp ? spawns) "spawns: ${builtins.toJSON omp.spawns}"
      ++ lib.optional (omp ? tools) "tools: ${lib.concatStringsSep ", " omp.tools}";
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  # OMP's task tool drops every context file named AGENTS.md from a subagent, so the global
  # instructions reach role subagents only through their own prompts.
  renderAgent = name: agent: ''
    ${renderFrontmatter name agent}

    ${lib.trim agent.prompt}

    ${lib.trim instructions}
  '';
in
{
  homeFiles = lib.mapAttrs' (
    name: agent: lib.nameValuePair ".omp/agent/agents/${name}.md" { text = renderAgent name agent; }
  ) (lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents);
}
