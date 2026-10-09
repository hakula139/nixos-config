# ==================================================================================================
# Claude Code Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  commandText = entry: lib.concatStringsSep " " entry.argv;

  toBashRules = entries: map (entry: "Bash(${commandText entry} *)") entries;

  softDenyClearance = ''
    Allow when the user explicitly approves the action, including approval already given in
    the conversation. Otherwise, block it even if an allow rule would permit it.
  '';

  toProseRules =
    entries:
    map (
      entry:
      let
        name = entry.name or "`${commandText entry}`";
      in
      "${name}: ${lib.trim entry.reason}"
    ) entries;

  toSoftDenyRules =
    entries: map (rule: "${rule} ${lib.trim softDenyClearance}") (toProseRules entries);
in
{
  permissions = {
    defaultMode = "auto";
    allow = import ./allow-rules.nix;
    deny = toBashRules policy.denies;
  };
  skipDangerousModePermissionPrompt = true;

  autoMode = {
    classifyAllShell = true;
    environment = [
      "$defaults"
      "Source control: github.com/hakula139 and all repos under it"
    ];
    allow = [ "$defaults" ] ++ toProseRules policy.allows;
    soft_deny = [ "$defaults" ] ++ toSoftDenyRules (policy.gates ++ policy.softDenies);
  };
}
