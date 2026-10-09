# ==================================================================================================
# OMP Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  toBashRules =
    approval: entries:
    lib.concatMap (
      entry:
      let
        command = lib.concatStringsSep " " entry.argv;
      in
      map (match: { inherit match approval; }) [
        command
        "${command} *"
      ]
    ) entries;
in
{
  tools = {
    # In yolo mode, critical-command overrides can bypass Bash prompt rules.
    approvalMode = "write";
    approval = {
      bash = "allow";
      # Eval can execute shells without passing through Bash's command rules.
      eval = "prompt";
    };
  };

  bash.patterns = toBashRules "deny" policy.denies ++ toBashRules "prompt" policy.gates;
}
