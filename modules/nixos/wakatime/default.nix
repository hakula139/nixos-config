{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Wakatime (Time Tracking)
# ==============================================================================

let
  cfg = config.hakula.wakatime;
  userCfg = config.users.users.${cfg.user};
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.wakatime = {
    enable = lib.mkEnableOption "Wakatime config";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakula.user.name;
      description = "User to configure Wakatime for";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = "hakula.wakatime.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.wakatime-config = secrets.mkSecret {
      name = "wakatime-config";
      owner = cfg.user;
      group = userCfg.group;
      path = "${userCfg.home}/.wakatime.cfg";
    };
  };
}
