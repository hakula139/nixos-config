# ==============================================================================
# hakula-linux System Manager Configuration
# ==============================================================================

{
  lib,
  secrets,
  ...
}:

{
  imports = [
    ../_profiles/workstation-linux-system
  ];

  # ----------------------------------------------------------------------------
  # Secret Overrides
  # ----------------------------------------------------------------------------
  age.secrets.github-pat.file = lib.mkForce (secrets.secretFile "github/pat-work");
}
