{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Claude Code (AI Code Assistant)
# ==============================================================================

let
  cfg = config.hakula.claude-code;
  userCfg = config.users.users.${cfg.user};
  secretsDir = secrets.secretsPath userCfg.home;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.claude-code = {
    enable = lib.mkEnableOption "Claude Code secrets";

    user = lib.mkOption {
      type = lib.types.str;
      default = "hakula";
      description = "User to store Claude Code secrets for";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = "hakula.claude-code.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.claude-code-oauth-token = secrets.mkSecret {
      name = "claude-code-oauth-token";
      owner = cfg.user;
      group = userCfg.group;
      path = "${secretsDir}/claude-code-oauth-token";
    };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = secrets.mkSecretsDir userCfg userCfg.group;
  };
}
