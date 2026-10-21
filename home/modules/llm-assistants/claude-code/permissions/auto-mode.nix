# ==================================================================================================
# Claude Code Auto Mode
# ==================================================================================================

{
  lib,
  policy,
}:

let
  softDenyClearance = ''
    Allow when the user explicitly approves the action, including approval already given in
    the conversation. Otherwise, block it even if an allow rule would permit it.
  '';

  toLine = text: lib.replaceStrings [ "\n" ] [ " " ] (lib.trim text);

  toProseRules =
    entries:
    map (
      entry:
      let
        name = entry.name or "`${entry.command}`";
      in
      "${name}: ${toLine entry.reason}"
    ) entries;

  mcpGates = map (gate: {
    name = "`mcp__${gate.displayName}__${gate.tool}`";
    inherit (gate) reason;
  }) policy.mcpGates;

  toSoftDenyRules = entries: map (rule: "${rule} ${toLine softDenyClearance}") (toProseRules entries);
in
{
  classifyAllShell = false;
  environment = [
    "$defaults"
    "Source control: github.com/hakula139 and all repos under it"
  ];

  allow = [ "$defaults" ] ++ toProseRules policy.allows.policies;
  soft_deny = [
    "$defaults"
  ]
  ++ toSoftDenyRules (policy.gates.commands ++ mcpGates ++ policy.gates.policies);
}
