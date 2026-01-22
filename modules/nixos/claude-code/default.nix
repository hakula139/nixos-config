{
  config,
  lib,
  ...
}:

# ==============================================================================
# Claude Code (AI Code Assistant)
# ==============================================================================

let
  cfg = config.hakula.claude-code;
  userCfg = config.users.users.${cfg.user};
  secretsDir = "${userCfg.home}/.secrets";
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
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.claude-code-oauth-token = {
      file = ../../../secrets/shared/claude-code-oauth-token.age;
      path = "${secretsDir}/claude-code-oauth-token";
      owner = cfg.user;
      group = userCfg.group;
      mode = "0600";
    };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${secretsDir} 0700 ${cfg.user} ${userCfg.group} -"
    ];
  };
}
