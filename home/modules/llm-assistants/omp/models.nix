# ==============================================================================
# OMP Model Configuration
# ==============================================================================

{
  pkgs,
  lib,
  profileDefinitions,
  profiles,
  secretPath,
}:

let
  inherit (profileDefinitions) familyApis providers;

  mkModel = channel: model: {
    inherit (model)
      name
      contextWindow
      maxTokens
      input
      reasoning
      thinking
      ;
    id = model.channelId.${channel};
    cost = model.channelCost.${channel};
  };

  mkProvider =
    _: profile:
    let
      api = familyApis.${profile.family};
      provider = providers.${profile.provider};
    in
    {
      inherit api;
      baseUrl = provider.apiUrls.${api};
      auth = "apiKey";
      apiKey = "!${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg (secretPath provider.tokenSecret)}";
      authHeader = true;
      models = map (mkModel profile.channel) (lib.unique (builtins.attrValues profile.models));
    }
    // lib.optionalAttrs (profile.family == "claude") {
      compat.supportsLongCacheRetention = true;
    }
    // lib.optionalAttrs (profile.channel == "local") {
      modelOverrides."Kimi-K3".compat.supportsImageDetailOriginal = false;
    }
    // lib.optionalAttrs (api == "openai-responses") {
      compat = {
        # Override unrelated bundled-provider compatibility inherited for custom models.
        supportsReasoningEffort = true;
      }
      // lib.optionalAttrs (profile.family == "gpt") {
        supportsLongPromptCacheRetention = true;
      };
    };
in
{
  providers = lib.mapAttrs mkProvider profiles;
}
