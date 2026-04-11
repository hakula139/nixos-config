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
  hmUser = config.home-manager.users.${cfg.user} or { };

  secretsDir = secrets.secretsPath userCfg.home;
  requiredSecrets = hmUser.hakula.claude-code.auth._provision.requiredSecrets or [ ];
  requiresSecret = name: lib.elem name requiredSecrets;
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

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.claude-code-api-key = lib.mkIf (requiresSecret "claude-code-api-key") (
      secrets.mkSecret {
        name = "claude-code-api-key";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/claude-code-api-key";
      }
    );

    age.secrets.claude-code-oauth-token = lib.mkIf (requiresSecret "claude-code-oauth-token") (
      secrets.mkSecret {
        name = "claude-code-oauth-token";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/claude-code-oauth-token";
      }
    );

    age.secrets.litellm-api-key = lib.mkIf (requiresSecret "litellm-api-key") (
      secrets.mkSecret {
        name = "litellm-api-key";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/litellm-api-key";
      }
    );

    age.secrets.corp-cachain-crt = lib.mkIf (requiresSecret "corp-cachain.crt") (
      secrets.mkSecret {
        name = "corp-cachain.crt";
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/corp-cachain.crt";
      }
    );
  };
}
