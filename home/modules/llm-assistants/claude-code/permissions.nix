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

  # The built-in `Git Push Destination` allow exception would otherwise clear
  # the `git push` gate for pushes to the session's own repo.
  softDenyClearance = "Blocked unless the user explicitly asked for it. No allow exception clears it.";

  toSoftDenyRules =
    entries:
    map (
      entry:
      let
        name = entry.name or "`${commandText entry}`";
      in
      "${name}: ${entry.reason} ${softDenyClearance}"
    ) entries;
in
{
  permissions = {
    defaultMode = "auto";
    allow = import ./allow-rules.nix;
    deny = toBashRules policy.denies;
  };
  skipDangerousModePermissionPrompt = true;

  # ----------------------------------------------------------------------------
  # Auto mode
  # ----------------------------------------------------------------------------
  autoMode = {
    classifyAllShell = true;
    environment = [
      "$defaults"
      "Source control: github.com/hakula139 and all repos under it"
    ];
    soft_deny = [ "$defaults" ] ++ toSoftDenyRules (policy.gates ++ policy.softDenies);
  };
}
