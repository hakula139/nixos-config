# ==============================================================================
# Claude Code Custom Agents
# ==============================================================================

{
  lib,
  enabledAgents,
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

  instructionsDir = ../../shared/instructions;

  # The gate hook and this role state one doctrine, so both compose the same
  # fragments over the same prompt body. `prose-polish` deliberately gets only
  # the positive `phrasing.md`, since a rule checklist measured worst as a
  # rewrite frame.
  commentGateFragments = {
    "@comments@" = "${instructionsDir}/comments.md";
    "@proseTics@" = "${instructionsDir}/prose-tics.md";
    "@proseTicsZh@" = "${instructionsDir}/prose-tics-zh.md";
  };

  commentGateBody =
    builtins.replaceStrings (builtins.attrNames commentGateFragments)
      (map builtins.readFile (builtins.attrValues commentGateFragments))
      (builtins.readFile ../../shared/hooks/post-tool-use/comment-gate/comment-gate-prompt.md);

  allAgents = lib.mapAttrs renderAgent sharedAgents // {
    codex-worker = builtins.readFile ./codex-worker.md;
    comment-gate = renderAgent "comment-gate" {
      description = "Audits comments and docstrings against the owner's default-to-none doctrine. Use to sweep a file or a diff for comments that should be dropped or tightened.";
      prompt = commentGateBody;
      claude = {
        color = "gray";
        model = "sonnet";
        permissionMode = "plan";
      };
    };
  };
in
lib.filterAttrs (name: _: lib.elem name enabledAgents) allAgents
