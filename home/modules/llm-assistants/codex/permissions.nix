# ==================================================================================================
# Codex Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  toPattern =
    command: lib.concatStringsSep ", " (map (arg: ''"${arg}"'') (lib.splitString " " command));

  gateRules = map (gate: ''
    prefix_rule(
        pattern = [${toPattern gate.command}],
        decision = "prompt",
        justification = "${gate.reason}",
    )
  '') policy.gates.commands;

  # Codex applies the strictest matching decision, and `allow` runs a command outside the sandbox
  # without review, so only read-only commands render as allows.
  allowRules = map (command: ''
    prefix_rule(
        pattern = [${toPattern command}],
        decision = "allow",
    )
  '') policy.allows.commands.readOnly;

  toMcpApprovals =
    mode: entries:
    lib.foldl' lib.recursiveUpdate { } (
      map (entry: { ${entry.server}.tools.${entry.tool}.approval_mode = mode; }) entries
    );

  mcpGates = map (gate: {
    name = "`${gate.tool}` on the ${gate.displayName} MCP server";
    inherit (gate) reason;
  }) policy.mcpGates;

  toCodeList = lib.concatMapStringsSep ", " (item: "`${item}`");

  argumentGates = map (gate: {
    name = "${toCodeList gate.commands} with ${toCodeList gate.arguments}";
    inherit (gate) reason;
  }) policy.gates.arguments;

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
  rules = lib.concatStringsSep "\n" (gateRules ++ allowRules);

  mcpApprovals = lib.recursiveUpdate (toMcpApprovals "approve" policy.mcpAllows) (
    toMcpApprovals "prompt" policy.mcpGates
  );

  extraPolicy = ''
    ## Allowed without user approval

    ${toPolicyItems policy.allows.policies}

    ## Requires the user's explicit approval, including approval given earlier in the conversation

    ${toPolicyItems (policy.gates.commands ++ argumentGates ++ mcpGates ++ policy.gates.policies)}
  '';
}
