# ==============================================================================
# OpenCode Permissions
# ==============================================================================

{
  lib,
  policy,
}:

let
  # Each command gets a bare and a prefixed key so `rm` never matches `rmdir`.
  toBashRules =
    decision: entries:
    lib.listToAttrs (
      lib.concatMap (
        entry:
        let
          command = lib.concatStringsSep " " entry.argv;
        in
        [
          (lib.nameValuePair command decision)
          (lib.nameValuePair "${command} *" decision)
        ]
      ) entries
    );
in
{
  # OpenCode resolves permission.bash last-match-wins with no deny precedence,
  # and Nix serializes keys alphabetically (attrsets are unordered:
  # nix-community/home-manager#2519). Denies win today only because each is more
  # specific than its ask, so it sorts later (`agenix -r` after `agenix *`). A
  # broad deny with a narrower ask carve-out would silently degrade to a prompt.
  bash = {
    "*" = "allow";
  }
  // toBashRules "ask" policy.gates
  // toBashRules "deny" policy.denies;
}
