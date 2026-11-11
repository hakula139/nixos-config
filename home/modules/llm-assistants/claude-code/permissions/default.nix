# ==================================================================================================
# Claude Code Permissions
# ==================================================================================================

{
  lib,
  shared,
}:

let
  allowRules = import ./allow-rules.nix {
    inherit lib shared;
  };
  denyRules = import ./deny-rules.nix;
in
{
  permissions = {
    defaultMode = "auto";
    allow = allowRules;
    deny = denyRules;
  };
  skipDangerousModePermissionPrompt = true;

  autoMode = import ./auto-mode.nix {
    inherit lib shared;
  };
}
