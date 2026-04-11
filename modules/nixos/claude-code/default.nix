# ==============================================================================
# Claude Code (AI Code Assistant)
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

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

    auth = {
      method = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "api-key"
            "oauth-token"
            "gateway"
          ]
        );
        default = null;
        description = "Authentication method for Claude Code";
      };

      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Base URL for plain API key authentication";
      };
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakula.user.name;
      description = "User to store Claude Code secrets for";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasAttr cfg.user config.users.users;
        message = "hakula.claude-code.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.claude-code-api-key = lib.mkIf (cfg.auth.method == "api-key") (
      secrets.mkSecret {
        name = "claude-code-api-key";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/claude-code-api-key";
      }
    );

    age.secrets.claude-code-oauth-token = lib.mkIf (cfg.auth.method == "oauth-token") (
      secrets.mkSecret {
        name = "claude-code-oauth-token";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/claude-code-oauth-token";
      }
    );

    age.secrets.litellm-api-key = lib.mkIf (cfg.auth.method == "gateway") (
      secrets.mkSecret {
        name = "litellm-api-key";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/litellm-api-key";
      }
    );

    age.secrets.corp-cachain-crt = lib.mkIf (cfg.auth.method == "gateway") (
      secrets.mkSecret {
        name = "corp-cachain.crt";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/corp-cachain.crt";
      }
    );
  };
}
