# ==================================================================================================
# User Secrets
# ==================================================================================================
# Declares a SOPS secret for each entry the primary user's Home Manager configuration requires.
# ==================================================================================================

{
  config,
  repoLib,
  ...
}:

let
  user = config.hakula.user;
  homeConfig = config.home-manager.users.${user.name} or { };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config.sops.secrets = repoLib.secrets.mkRequiredUserSecrets { inherit homeConfig user; };
}
