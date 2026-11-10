# ==================================================================================================
# Claude Code Permissions
# ==================================================================================================

{
  lib,
  shared,
}:

let
  skillScriptPaths = map (
    script: "${shared.claudeConfigDir}/skills/${script.skill}/${script.file}"
  ) shared.skillScripts;

  allowRules = import ./allow-rules.nix {
    inherit
      lib
      shared
      skillScriptPaths
      ;
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
