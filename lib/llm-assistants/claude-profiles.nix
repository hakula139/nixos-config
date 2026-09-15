# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  lib,
  corpHosts,
  modelCatalog,
  enableCorpGateway ? false,
}:

let
  inherit (corpHosts) llmGatewayUrl;
  inherit (modelCatalog) defaults models;

  claudeModels = {
    opus = defaults.claude.flagship;
    sonnet = defaults.claude.standard;
    haiku = defaults.claude.mini;
  };

  gptModels = {
    opus = defaults.gpt.flagship;
    sonnet = defaults.gpt.standard;
    haiku = defaults.gpt.mini;
  };

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
    modelOverrides = claudeModels;
  };

  official-token = {
    type = "oauth-token";
    tokenSecret = "llm-assistants/claude-oauth-token";
    modelOverrides = claudeModels;
  };

  ikuncode = {
    type = "api-key";
    tokenSecret = "llm-assistants/ikuncode-api-key";
    baseUrl = "https://api.ikuncode.cc";
    modelOverrides = claudeModels;
  };

  yescode = {
    type = "api-key";
    tokenSecret = "llm-assistants/yescode-api-key";
    baseUrl = "https://co.yes.vg";
    modelOverrides = claudeModels;
  };
}
// lib.optionalAttrs enableCorpGateway {
  corp-gateway-bedrock = corpGatewayCommon // {
    modelOverrides = lib.mapAttrs (_: id: models.${id}.gatewayId.bedrock) claudeModels;
  };

  corp-gateway-openai = corpGatewayCommon // {
    modelFamily = "gpt";
    modelOverrides = lib.mapAttrs (_: id: models.${id}.gatewayId.openai) gptModels;
    extraEnv = corpGatewayCommon.extraEnv // {
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = toString models.${gptModels.opus}.autoCompactTokens;
    };
  };
}
