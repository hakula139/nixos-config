# ==================================================================================================
# Antigravity Authentication
# ==================================================================================================

{
  secretPath,
  ...
}:

let
  apiKeySecret = "llm-assistants/ai-studio-api-key";
in
{
  agents = {
    agy = {
      enable = true;
      auth = {
        defaultProfile = "official";
        enabledProfiles = [
          "official"
          "ai-studio"
        ];
      };
    };

    providers.ai-studio.apiKeyFile = secretPath apiKeySecret;

    profiles.ai-studio = {
      provider = "ai-studio";
      family = "gemini";
      clients = [ "agy" ];
    };
  };

  hakula.secrets.required.${apiKeySecret} = { };
}
