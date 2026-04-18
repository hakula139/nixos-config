# ==============================================================================
# Claude Code Auth Profiles — corp subset
# ==============================================================================
# Layered on top of `lib/claude-profiles.nix` by hosts with workstation-level
# agenix access (workstations + hakula-devvm). Do NOT import on servers —
# `llm-assistants/litellm-api-key.age` and `llm-assistants/corp-cachain.crt.age`
# are not decryptable by server host keys.
# ==============================================================================

let
  corpDomain = import ./corp-domain.nix;
in
{
  corp-gateway = {
    type = "api-key";
    tokenSecret = "llm-assistants/litellm-api-key";
    baseUrl = "https://gw.llm.${corpDomain}";
    modelOverrides = {
      opus = "bedrock/global.anthropic.claude-opus-4-6-v1";
      sonnet = "bedrock/global.anthropic.claude-sonnet-4-6";
      haiku = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
    };
    extraSecretEnv = {
      NODE_EXTRA_CA_CERTS = "llm-assistants/corp-cachain.crt";
    };
  };
}
