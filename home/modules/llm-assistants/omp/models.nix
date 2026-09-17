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

  mkModel = gateway: model: {
    inherit (model)
      name
      contextWindow
      maxTokens
      input
      reasoning
      thinking
      ;
    id = model.gatewayId.${gateway};
    cost = model.gatewayCost.${gateway};
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
      models = map (mkModel profile.gateway) (lib.unique (builtins.attrValues profile.models));
    }
    // lib.optionalAttrs (api == "openai-responses") {
      # Override unrelated bundled-provider compatibility inherited for custom models.
      compat.supportsReasoningEffort = true;
    };
in
{
  providers = lib.mapAttrs mkProvider profiles;
}
