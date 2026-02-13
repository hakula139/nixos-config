{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Cachix (Binary Cache Tooling)
# ==============================================================================

let
  cfg = config.hakula.cachix;
  userCfg = config.users.users.${cfg.user};
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.cachix = {
    enable = lib.mkEnableOption "Cachix auth token secret";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakula.user.name;
      description = "User to own the Cachix auth token secret";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasAttr cfg.user config.users.users;
        message = "hakula.cachix.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.cachix-auth-token = secrets.mkSecret {
      name = "cachix-auth-token";
      owner = cfg.user;
      inherit (userCfg) group;
    };
  };
}
