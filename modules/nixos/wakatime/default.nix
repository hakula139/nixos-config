{
  config,
  lib,
  ...
}:

# ==============================================================================
# Wakatime Configuration
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
      default = "hakula";
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
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.wakatime-config = {
      file = ../../../secrets/shared/wakatime-config.age;
      path = "${userCfg.home}/.wakatime.cfg";
      owner = cfg.user;
      group = userCfg.group;
      mode = "0600";
    };
  };
}
