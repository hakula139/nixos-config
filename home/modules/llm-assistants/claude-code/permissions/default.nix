# ==================================================================================================
# Claude Code Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  allowRules = import ./allow-rules.nix { inherit lib policy; };
  denyRules = import ./deny-rules.nix;
in
{
  permissions = {
    defaultMode = "auto";
    allow = allowRules;
    deny = denyRules;
  };

  skipDangerousModePermissionPrompt = true;
  autoMode = import ./auto-mode.nix { inherit lib policy; };
}
