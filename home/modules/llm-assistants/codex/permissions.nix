# ==================================================================================================
# Codex Permissions
# ==================================================================================================

{
  lib,
  shared,
}:

let
  policy = shared.permissions;

  toPattern = command: lib.concatStringsSep ", " (map builtins.toJSON (lib.splitString " " command));

  toAllowRule = pattern: ''
    prefix_rule(
        pattern = [${pattern}],
        decision = "allow",
    )
  '';

  gateRules = map (gate: ''
    prefix_rule(
        pattern = [${toPattern gate.command}],
        decision = "prompt",
        justification = "${gate.reason}",
    )
  '') policy.gates.commands;

  # Codex applies the strictest matching decision, and `allow` runs a command outside the sandbox
  # without review, so only read-only commands and the scripts of skills this repository owns
  # render as allows.
  allowRules = map (command: toAllowRule (toPattern command)) policy.allows.commands.readOnly;

  skillRules = map (path: toAllowRule (builtins.toJSON path)) (
    shared.mkSkillScriptPaths "${shared.codexConfigDir}/skills"
  );

  toMcpApprovals =
    mode: entries:
    lib.foldl' lib.recursiveUpdate { } (
      map (entry: { ${entry.server}.tools.${entry.tool}.approval_mode = mode; }) entries
    );

  mcpGates = map (gate: {
    name = "`${gate.tool}` on the ${gate.displayName} MCP server";
    inherit (gate) reason;
  }) policy.mcpGates;

  toPolicyItems = lib.concatMapStringsSep "\n" (
    entry:
    let
      name = entry.name or "`${entry.command}`";
      reason = lib.replaceStrings [ "\n" ] [ "\n  " ] (lib.trim entry.reason);
    in
    "- ${name}: ${reason}"
  );
in
{
  rules = lib.concatStringsSep "\n" (gateRules ++ allowRules ++ skillRules);

  mcpApprovals = lib.recursiveUpdate (toMcpApprovals "approve" policy.mcpAllows) (
    toMcpApprovals "prompt" policy.mcpGates
  );

  extraPolicy = ''
    ## Allowed without user approval

    ${toPolicyItems policy.allows.policies}

    ## Requires the user's explicit approval, including approval given earlier in the conversation

    ${toPolicyItems (policy.gates.commands ++ mcpGates ++ policy.gates.policies)}
  '';
}
