# ==============================================================================
# Claude Code Custom Agents
# ==============================================================================

{
  lib,
  sharedAgents,
  enabledAgents,
  modelAliases,
}:

let
  renderIndentedLines =
    value: map (line: "  ${line}") (lib.filter (line: line != "") (lib.splitString "\n" value));

  renderField =
    settings: field: lib.optional (settings ? ${field}) "${field}: ${toString settings.${field}}";

  renderFrontmatter =
    name: agent:
    let
      settings = agent.claude // {
        model = modelAliases.${agent.modelTier};
        inherit (agent) effort;
      };
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
  };
in
{
  files = lib.filterAttrs (name: _: lib.elem name enabledAgents) allAgents;
}
