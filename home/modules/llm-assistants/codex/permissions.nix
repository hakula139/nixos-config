# ==================================================================================================
# Codex Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  toRules =
    decision: entries:
    map (
      entry:
      let
        pattern = lib.concatStringsSep ", " (map (arg: ''"${arg}"'') entry.argv);
      in
      ''
        prefix_rule(
            pattern = [${pattern}],
            decision = "${decision}",
            justification = "${entry.reason}",
        )
      ''
    ) entries;
in
lib.concatStringsSep "\n" (toRules "prompt" policy.gates)
