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

  mkProvisioned =
    secretName:
    lib.mkIf (lib.elem secretName requiredSecrets) (
      secrets.mkSecret {
        name = secretName;
        owner = cfg.user;
        inherit (userCfg) group;
        path = "${secretsDir}/${secretName}";
      }
    );
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
    age.secrets = {
      claude-code-api-key = mkProvisioned "claude-code-api-key";
      claude-code-oauth-token = mkProvisioned "claude-code-oauth-token";
      litellm-api-key = mkProvisioned "litellm-api-key";
      corp-cachain-crt = mkProvisioned "corp-cachain.crt";
    };
  };
}
