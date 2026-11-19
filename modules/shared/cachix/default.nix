# ==================================================================================================
# Cachix (Binary Cache Tooling)
# ==================================================================================================

{
  config,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.cachix;
  user = config.hakula.user;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.cachix.enable = lib.mkEnableOption "Cachix auth token secret";

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    age.secrets.cachix-auth-token = repoLib.secrets.mkSecret {
      name = "cachix/auth-token";
      owner = user.name;
      inherit (user) group;
    };
  };
}
