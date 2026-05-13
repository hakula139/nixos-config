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
    tokenSecret = "llm-assistants/bifrost-api-key";
    baseUrl = "https://gw1.llm.${corpDomain}/anthropic";
    extraEnv = {
      CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
    };
    extraSecretEnv = {
      NODE_EXTRA_CA_CERTS = "llm-assistants/corp-cachain.crt";
    };
  };
}
