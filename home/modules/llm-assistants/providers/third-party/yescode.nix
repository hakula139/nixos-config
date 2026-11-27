# ==================================================================================================
# Yescode Third-Party Relay Provider
# ==================================================================================================

{
  secretPath,
}:

let
  apiKeySecret = "llm-assistants/yescode-api-key";
in
{
  providers.yescode = {
    apiUrls.anthropic-messages = "https://co.yes.vg";
    apiKeyFile = secretPath apiKeySecret;
  };

  profiles.yescode = {
    provider = "yescode";
    family = "claude";
    nativeWebSearch = false;
    clients = [
      "claude-code"
      "oxide-code"
    ];
  };

  requiredSecrets = [ apiKeySecret ];
}
