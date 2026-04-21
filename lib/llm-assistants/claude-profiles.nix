# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  lib,
  enableCorpGateway ? false,
}:

let
  corpDomain = import ../corp-domain.nix;
in
{
  official = {
    type = "subscription";
  };

  official-token = {
    type = "oauth-token";
    tokenSecret = "llm-assistants/claude-oauth-token";
  };

  ikuncode = {
    type = "api-key";
    tokenSecret = "llm-assistants/ikuncode-api-key";
    baseUrl = "https://api.ikuncode.cc";
  };

  yescode = {
    type = "api-key";
    tokenSecret = "llm-assistants/yescode-api-key";
    baseUrl = "https://co.yes.vg";
  };
}
// lib.optionalAttrs enableCorpGateway {
  corp-gateway = {
    type = "api-key";
    tokenSecret = "llm-assistants/litellm-api-key";
    baseUrl = "https://gw.llm.${corpDomain}";
    modelOverrides = {
      opus = "bedrock/global.anthropic.claude-opus-4-7";
      sonnet = "bedrock/global.anthropic.claude-sonnet-4-6";
      haiku = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
    };
    extraSecretEnv = {
      NODE_EXTRA_CA_CERTS = "llm-assistants/corp-cachain.crt";
    };
  };
}
