# ==============================================================================
# MCP (Model Context Protocol)
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

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
      default = config.hakula.llm-assistants.user;
      description = "User to store MCP secrets for";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasAttr cfg.user config.users.users;
        message = "hakula.mcp.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.confluence-pat = secrets.mkSecret {
      name = "confluence-pat";
      owner = cfg.user;
      inherit (userCfg) group;
      path = "${secretsDir}/confluence-pat";
    };

    age.secrets.brave-api-key = secrets.mkSecret {
      name = "brave-api-key";
      owner = cfg.user;
      inherit (userCfg) group;
      path = "${secretsDir}/brave-api-key";
    };

    age.secrets.context7-api-key = secrets.mkSecret {
      name = "context7-api-key";
      owner = cfg.user;
      inherit (userCfg) group;
      path = "${secretsDir}/context7-api-key";
    };

    age.secrets.github-pat = secrets.mkSecret {
      name = "github-pat-personal";
      owner = cfg.user;
      inherit (userCfg) group;
      path = "${secretsDir}/github-pat";
    };
  };
}
