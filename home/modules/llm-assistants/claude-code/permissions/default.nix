# ==============================================================================
# Claude Code Permissions
# ==============================================================================

{
  lib,
  policy,
}:

let
  commandText = entry: lib.concatStringsSep " " entry.argv;

  toBashRules = entries: map (entry: "Bash(${commandText entry} *)") entries;

  softDenyClearance = "Blocked unless the user explicitly approved the action. No allow exception clears it.";

  toProseRules =
    entries:
    map (
      entry:
      let
        name = entry.name or "`${commandText entry}`";
      in
      "${name}: ${entry.reason}"
    ) entries;

  toSoftDenyRules = entries: map (rule: "${rule} ${softDenyClearance}") (toProseRules entries);
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
