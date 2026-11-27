# ==================================================================================================
# Ikuncode Third-Party Relay Provider
# ==================================================================================================

{
  secretPath,
}:

let
  apiKeySecret = "llm-assistants/ikuncode-api-key";
in
{
  providers.ikuncode = {
    apiUrls.anthropic-messages = "https://api.ikuncode.cc";
    apiKeyFile = secretPath apiKeySecret;
  };

  profiles.ikuncode = {
    provider = "ikuncode";
    family = "claude";
    nativeWebSearch = false;
    clients = [
      "claude-code"
      "oxide-code"
    ];
  };

  requiredSecrets = [ apiKeySecret ];
}
