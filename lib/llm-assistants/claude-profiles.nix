# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  lib,
  corpHosts,
  enableCorpGateway ? false,
}:

let
  inherit (corpHosts) llmGatewayUrl;

  corpGatewayCommon = {
    type = "api-key";
    tokenSecret = "llm-assistants/bifrost-api-key";
    baseUrl = "${llmGatewayUrl}/anthropic";
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
      # Bedrock rejects Fable 5.1 while the AWS account's data retention mode is
      # 'default', so this one model routes through openrouter.
      fable = "openrouter/anthropic/claude-fable-5.1";
      opus = "bedrock/global.anthropic.claude-opus-5";
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
