{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# MCP (Model Context Protocol)
# ==============================================================================

let
  cfg = config.hakula.mcp;
  userCfg = config.users.users.${cfg.user};
  secretsDir = secrets.secretsPath userCfg.home;
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
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.brave-api-key = secrets.mkSecret {
      name = "brave-api-key";
      owner = cfg.user;
      group = userCfg.group;
      path = "${secretsDir}/brave-api-key";
    };

    age.secrets.context7-api-key = secrets.mkSecret {
      name = "context7-api-key";
      owner = cfg.user;
      group = userCfg.group;
      path = "${secretsDir}/context7-api-key";
    };

    age.secrets.github-pat = secrets.mkSecret {
      name = "github-pat";
      owner = cfg.user;
      group = userCfg.group;
      path = "${secretsDir}/github-pat";
    };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = secrets.mkSecretsDir userCfg userCfg.group;
  };
}
