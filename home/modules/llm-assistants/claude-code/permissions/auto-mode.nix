# ==================================================================================================
# Claude Code Auto Mode
# ==================================================================================================

{
  lib,
  policy,
  skillScripts,
  skillsDir,
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

  skillScriptPaths = map (script: "${skillsDir}/${script.skill}/${script.file}") skillScripts;

  exemptSkillScripts =
    entry:
    entry
    // lib.optionalAttrs (entry.name == "Shell edits to repository files" && skillScriptPaths != [ ]) {
      reason = ''
        ${lib.trim entry.reason} The scripts bundled with a shared skill rewrite files in place by
        their own rules, so this rule does not cover them when run from their installed paths:
        ${lib.concatMapStringsSep ", " (path: "`${path}`") skillScriptPaths}.
      '';
    };
in
{
  classifyAllShell = false;
  environment = [
    "$defaults"
    "Source control, in addition to the trusted repo and its remotes: ${policy.sourceControl.ownRepositories}"
  ];

  allow = [ "$defaults" ] ++ toProseRules policy.allows.policies;
  soft_deny = [
    "$defaults"
  ]
  ++ toSoftDenyRules (
    policy.gates.commands ++ mcpGates ++ map exemptSkillScripts policy.gates.policies
  );
}
