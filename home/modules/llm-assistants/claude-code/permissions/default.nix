# ==================================================================================================
# Claude Code Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

{
  permissions = {
    defaultMode = "auto";
    allow = import ./allow-rules.nix;
    deny = import ./deny-rules.nix;
  };

  skipDangerousModePermissionPrompt = true;
  autoMode = import ./auto-mode.nix { inherit lib policy; };
}
