# ==============================================================================
# Claude Code (AI Code Assistant)
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.claude-code;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.claude-code = {
    enable = lib.mkEnableOption "Claude Code secrets";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakula.llm-assistants.user;
      description = "User to store Claude Code secrets for";
    };

    defaultProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Default Claude Code auth profile to activate on first build. Bridges to
        `home-manager.users.<user>.hakula.claude-code.auth.defaultProfile` via
        `lib.mkDefault`, so HM-level assignments still take precedence.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasAttr cfg.user config.users.users;
        message = "hakula.claude-code.user (${cfg.user}) must exist in config.users.users.*";
      }
      {
        assertion = lib.hasAttr cfg.user config.home-manager.users;
        message = "hakula.claude-code.user (${cfg.user}) must exist in home-manager.users.*";
      }
    ];

    # ------------------------------------------------------------------------
    # Propagate defaultProfile to the HM user
    # ------------------------------------------------------------------------
    home-manager.users.${cfg.user}.hakula.claude-code.auth.defaultProfile =
      lib.mkDefault cfg.defaultProfile;

  };
}
