# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  lib,
  corpDomain,
  enableCorpGateway ? false,
}:

let
  corpGatewayCommon = {
    type = "api-key";
    tokenSecret = "llm-assistants/bifrost-api-key";
    baseUrl = "https://gw.llm.${corpDomain}/anthropic";
    extraEnv = {
      CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
    };
    extraSecretEnv = {
      NODE_EXTRA_CA_CERTS = "llm-assistants/corp-cachain.crt";
    };
  };
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
  corp-gateway-bedrock = corpGatewayCommon // {
    modelOverrides = {
      opus = "bedrock/global.anthropic.claude-opus-4-8";
      sonnet = "bedrock/global.anthropic.claude-sonnet-5";
      haiku = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
    };
  };

  corp-gateway-openai = corpGatewayCommon // {
    modelOverrides = {
      opus = "openai/gpt-5.6-sol";
      sonnet = "openai/gpt-5.6-terra";
      haiku = "openai/gpt-5.6-luna";
    };
    extraEnv = corpGatewayCommon.extraEnv // {
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "250000";
    };
  };
}
