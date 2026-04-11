# ==============================================================================
# Claude Code Authentication
# ==============================================================================

{
  config,
  lib,
  secrets,
  isNixOS ? false,
}:

let
  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;
  corpDomain = import ../../../../lib/corp-domain.nix;

  isOAuthToken = cfg.auth.method == "oauth-token";
  isApiKey = cfg.auth.method == "api-key";
  isGateway = cfg.auth.method == "gateway";
  isApiAuth = isApiKey || isGateway;

  secretFile = name: lib.escapeShellArg "${secretsDir}/${name}";

  apiAuthDefs = {
    api-key = {
      tokenSecret = "claude-code-api-key";
      defaultBaseUrl = "https://co.yes.vg";
      extraEnv = { };
      extraWrapArgs = [ ];
      extraSecrets = [ ];
    };

    gateway = {
      tokenSecret = "litellm-api-key";
      defaultBaseUrl = "https://gw.llm.${corpDomain}/";
      extraEnv = {
        ANTHROPIC_DEFAULT_OPUS_MODEL = "bedrock/global.anthropic.claude-opus-4-6-v1";
        ANTHROPIC_DEFAULT_SONNET_MODEL = "bedrock/global.anthropic.claude-sonnet-4-6";
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
      };
      extraWrapArgs = [
        "--set"
        "NODE_EXTRA_CA_CERTS"
        "${secretsDir}/corp-cachain.crt"
      ];
      extraSecrets = [ "corp-cachain.crt" ];
    };
  };

  apiAuth = if isApiAuth then apiAuthDefs.${cfg.auth.method} else null;

  requiredSecrets =
    if isOAuthToken then
      [ "claude-code-oauth-token" ]
    else if apiAuth != null then
      [ apiAuth.tokenSecret ] ++ apiAuth.extraSecrets
    else
      [ ];

  mkProvisioned =
    secretName:
    lib.mkIf (lib.elem secretName requiredSecrets) (
      secrets.mkHomeSecret {
        name = secretName;
        inherit homeDir;
      }
    );
in
{
  options = {
    method = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "oauth-token"
          "api-key"
          "gateway"
        ]
      );
      default = null;
      description = "Authentication method for Claude Code";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base URL for token-based authentication (`api-key`, `gateway`)";
    };

    _provision.requiredSecrets = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "claude-code-oauth-token"
          "claude-code-api-key"
          "litellm-api-key"
          "corp-cachain.crt"
        ]
      );
      internal = true;
      readOnly = true;
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !isApiAuth || cfg.auth.baseUrl != null;
          message = "hakula.claude-code: auth.baseUrl must be set when auth.method is `api-key` or `gateway`";
        }
      ];
      hakula.claude-code.auth._provision.requiredSecrets = requiredSecrets;
    }

    (lib.mkIf (apiAuth != null) {
      hakula.claude-code.auth.baseUrl = lib.mkDefault apiAuth.defaultBaseUrl;
    })

    (lib.mkIf (!isNixOS) {
      age.secrets = {
        claude-code-oauth-token = mkProvisioned "claude-code-oauth-token";
        claude-code-api-key = mkProvisioned "claude-code-api-key";
        litellm-api-key = mkProvisioned "litellm-api-key";
        corp-cachain-crt = mkProvisioned "corp-cachain.crt";
      };
    })
  ];

  wrapArgs =
    lib.optionals isOAuthToken [
      "--run"
      ''export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${secretFile "claude-code-oauth-token"})"''
    ]
    ++ lib.optionals (apiAuth != null) (
      [
        "--run"
        ''export ANTHROPIC_AUTH_TOKEN="$(cat ${secretFile apiAuth.tokenSecret})"''
      ]
      ++ apiAuth.extraWrapArgs
    );

  env = lib.optionalAttrs (apiAuth != null) (
    {
      ANTHROPIC_BASE_URL = cfg.auth.baseUrl;
    }
    // apiAuth.extraEnv
  );
}
