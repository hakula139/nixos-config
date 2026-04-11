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

  isApiKey = cfg.auth.method == "api-key";
  isOAuthToken = cfg.auth.method == "oauth-token";
  isGateway = cfg.auth.method == "gateway";

  apiKeyFile = lib.escapeShellArg "${secretsDir}/claude-code-api-key";
  oauthTokenFile = lib.escapeShellArg "${secretsDir}/claude-code-oauth-token";
  gatewayKeyFile = lib.escapeShellArg "${secretsDir}/litellm-api-key";
  gatewayCaCertFile = "${secretsDir}/corp-cachain.crt";

  requiredSecrets =
    if isApiKey then
      [ "claude-code-api-key" ]
    else if isOAuthToken then
      [ "claude-code-oauth-token" ]
    else if isGateway then
      [
        "litellm-api-key"
        "corp-cachain.crt"
      ]
    else
      [ ];

  tokenAuth =
    if isApiKey then
      {
        tokenFile = apiKeyFile;
        inherit (cfg.auth) baseUrl;
        extraEnv = { };
        extraWrapArgs = [ ];
      }
    else if isGateway then
      {
        tokenFile = gatewayKeyFile;
        baseUrl = "https://gw.llm.${corpDomain}/";
        extraEnv = {
          ANTHROPIC_DEFAULT_OPUS_MODEL = "bedrock/global.anthropic.claude-opus-4-6-v1";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "bedrock/global.anthropic.claude-sonnet-4-6";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
        };
        extraWrapArgs = [
          "--set"
          "NODE_EXTRA_CA_CERTS"
          gatewayCaCertFile
        ];
      }
    else
      null;
in
{
  options = {
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

    _provision.requiredSecrets = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "claude-code-api-key"
          "claude-code-oauth-token"
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
          assertion = !isApiKey || cfg.auth.baseUrl != null;
          message = "hakula.claude-code: auth.baseUrl must be set when auth.method is `api-key`";
        }
      ];
      hakula.claude-code.auth._provision.requiredSecrets = requiredSecrets;
    }

    (lib.mkIf (!isNixOS && isApiKey) {
      age.secrets.claude-code-api-key = secrets.mkHomeSecret {
        name = "claude-code-api-key";
        inherit homeDir;
      };
    })

    (lib.mkIf (!isNixOS && isOAuthToken) {
      age.secrets.claude-code-oauth-token = secrets.mkHomeSecret {
        name = "claude-code-oauth-token";
        inherit homeDir;
      };
    })

    (lib.mkIf (!isNixOS && isGateway) {
      age.secrets.litellm-api-key = secrets.mkHomeSecret {
        name = "litellm-api-key";
        inherit homeDir;
      };
      age.secrets.corp-cachain-crt = secrets.mkHomeSecret {
        name = "corp-cachain.crt";
        inherit homeDir;
      };
    })
  ];

  wrapArgs =
    lib.optionals isOAuthToken [
      "--run"
      ''export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${oauthTokenFile})"''
    ]
    ++ lib.optionals (tokenAuth != null) [
      "--run"
      ''export ANTHROPIC_AUTH_TOKEN="$(cat ${tokenAuth.tokenFile})"''
    ]
    ++ lib.optionals (tokenAuth != null) tokenAuth.extraWrapArgs;

  env = lib.optionalAttrs (tokenAuth != null) (
    {
      ANTHROPIC_BASE_URL = tokenAuth.baseUrl;
    }
    // tokenAuth.extraEnv
  );
}
