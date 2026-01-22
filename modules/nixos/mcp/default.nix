{
  config,
  lib,
  ...
}:

# ==============================================================================
# MCP (Model Context Protocol)
# ==============================================================================

let
  cfg = config.hakula.mcp;
  userCfg = config.users.users.${cfg.user};
  secretsDir = "${userCfg.home}/.secrets";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.mcp = {
    enable = lib.mkEnableOption "MCP secrets";

    user = lib.mkOption {
      type = lib.types.str;
      default = "hakula";
      description = "User to store MCP secrets for";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = "hakula.mcp.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.brave-api-key = {
      file = ../../../secrets/shared/brave-api-key.age;
      path = "${secretsDir}/brave-api-key";
      owner = cfg.user;
      group = userCfg.group;
      mode = "0400";
    };

    age.secrets.context7-api-key = {
      file = ../../../secrets/shared/context7-api-key.age;
      path = "${secretsDir}/context7-api-key";
      owner = cfg.user;
      group = userCfg.group;
      mode = "0400";
    };

    age.secrets.github-pat = {
      file = ../../../secrets/shared/github-pat.age;
      path = "${secretsDir}/github-pat";
      owner = cfg.user;
      group = userCfg.group;
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${secretsDir} 0700 ${cfg.user} ${userCfg.group} -"
    ];
  };
}
