# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  corpDomain,
  secretsDir,
}:

{
  official = {
    type = "oauth-token";
    tokenSecret = "claude-code-oauth-token";
  };

  corp-gateway = {
    type = "api-key";
    tokenSecret = "litellm-api-key";
    baseUrl = "https://gw.llm.${corpDomain}/";
    modelOverrides = {
      opus = "bedrock/global.anthropic.claude-opus-4-6-v1";
      sonnet = "bedrock/global.anthropic.claude-sonnet-4-6";
      haiku = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
    };
    extraEnv.NODE_EXTRA_CA_CERTS = "${secretsDir}/corp-cachain.crt";
    extraSecrets = [ "corp-cachain.crt" ];
  };

  yescode = {
    type = "api-key";
    tokenSecret = "claude-yescode-api-key";
    baseUrl = "https://co.yes.vg";
  };

  ikuncode = {
    type = "api-key";
    tokenSecret = "claude-ikuncode-api-key";
    baseUrl = "https://api.ikuncode.cc";
  };
}
