# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  lib,
  corpDomain,
  enableCorpGateway ? false,
}:

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
    tokenSecret = "llm-assistants/bifrost-api-key";
    baseUrl = "https://gw1.llm.${corpDomain}/anthropic";
    modelOverrides = {
      opus = "claude-opus-4-7";
      sonnet = "claude-sonnet-4-6";
      haiku = "claude-haiku-4-5-20251001";
    };
    extraEnv = {
      CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
    };
    extraSecretEnv = {
      NODE_EXTRA_CA_CERTS = "llm-assistants/corp-cachain.crt";
    };
  };
}
