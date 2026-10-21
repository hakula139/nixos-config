# ==================================================================================================
# OpenCode Permissions
# ==================================================================================================

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
          inherit (entry) command;
        in
        [
          (lib.nameValuePair command decision)
          (lib.nameValuePair "${command} *" decision)
        ]
      ) entries
    );
in
{
  # OpenCode resolves permission.bash last-match-wins, and Nix serializes keys alphabetically
  # (attrsets are unordered: nix-community/home-manager#2519). Each ask overrides `*` only because
  # `*` sorts before every command name.
  bash = {
    "*" = "allow";
  }
  // toBashRules "ask" policy.gates;
}
